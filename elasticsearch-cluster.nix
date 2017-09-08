{ config, lib, ... }:

with lib;

let
  cfg = config.services.elasticsearch-cluster;
in {
  options.services.elasticsearch-cluster = {
    enable = mkEnableOption "elasticsearch cluster service";

    image = mkOption {
      description = "Elasticsearch image to use";
      type = types.str;
      default = "quay.io/pires/docker-elasticsearch-kubernetes:5.5.0";
    };

    clusterName = mkOption {
      description = "Name of the cluster";
      type = types.str;
      default = "myes";
    };

    masternodes = {
      replicas = mkOption {
        description = "Number of master node replicas";
        default = 3;
        type = types.int;
      };

      minimumMasterNodes = mkOption {
        description = "Minimum number of master nodes";
        default = cfg.masternodes.replicas / 2 + 1;
        type = types.int;
      };

      memory = mkOption {
        description = "Memory reserved for master nodes";
        default = 2048;
        type = types.int;
      };

      cpu = mkOption {
        description = "CPU reserved for master nodes";
        default = "1000m";
        type = types.str;
      };
    };

    datanodes = {
      replicas = mkOption {
        description = "Number of data node replicas";
        default = 2;
        type = types.int;
      };

      memory = mkOption {
        description = "Memory reserved for master nodes";
        default = 2048;
        type = types.int;
      };

      cpu = mkOption {
        description = "CPU reserved for master nodes";
        default = "1000m";
        type = types.str;
      };

      storage = {
        size = mkOption {
          description = "Elasticsearch storage size";
          default = "100Gi";
          type = types.str;
        };

        class = mkOption {
          description = "Elasticsearh datanode storage class";
          type = types.str;
          default = "default";
        };
      };
    };

    clientnodes = {
      replicas = mkOption {
        description = "Number of client node replicas";
        default = 2;
        type = types.int;
      };

      memory = mkOption {
        description = "Memory reserved for client nodes";
        default = 2048;
        type = types.int;
      };

      cpu = mkOption {
        description = "CPU reserved for client nodes";
        default = "1000m";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.elasticsearch-master = {
      replicas = cfg.masternodes.replicas;

      dependencies = [
        "services/elasticsearch-discovery"
      ];

      pod.initContainers = [{
        name = "sysctl";
        image = "busybox";
        imagePullPolicy = "IfNotPresent";
        command = ["sysctl" "-w" "vm.max_map_count=262144"];
        security.privileged = true;
      }];

      pod.containers.es-master = {
        image = cfg.image;
        ports = [{ port = 9300; }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        }];

        env = {
          NAMESPACE.fieldRef.fieldPath = "metadata.namespace";
          NODE_NAME.fieldRef.fieldPath = "metadata.name";
          CLUSTER_NAME = cfg.clusterName;
          NUMBER_OF_MASTERS = cfg.masternodes.minimumMasterNodes;
          NODE_MASTER = "true";
          NODE_INGEST = "false";
          NODE_DATA = "false";
          HTTP_ENABLE = "false";
          ES_JAVA_OPTS="-Xms${toString (cfg.masternodes.memory * 3 / 4)}m -Xmx${toString (cfg.masternodes.memory * 3 / 4)}m";
        };

        requests.memory = "${toString cfg.masternodes.memory}Mi";
        requests.cpu = cfg.masternodes.cpu;
        limits.cpu = cfg.masternodes.cpu;

        security.capabilities.add = ["IPC_LOCK" "SYS_RESOURCE"];
      };

      pod.volumes.storage = {
        type = "emptyDir";
        options.medium = "";
      };
    };

    kubernetes.deployments.elasticsearch-client = {
      replicas = cfg.clientnodes.replicas;

      dependencies = [
        "services/elasticsearch"
        "services/elasticsearch-discovery"
      ];

      pod.initContainers = [{
        name = "sysctl";
        image = "busybox";
        imagePullPolicy = "IfNotPresent";
        command = ["sysctl" "-w" "vm.max_map_count=262144"];
        security.privileged = true;
      }];

      pod.containers.es-client = {
        image = cfg.image;
        ports = [{
          name = "http";
          port = 9200;
        } {
          name = "transport";
          port = 9300;
        }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        }];

        env = {
          NAMESPACE.fieldRef.fieldPath = "metadata.namespace";
          NODE_NAME.fieldRef.fieldPath = "metadata.name";
          CLUSTER_NAME = cfg.clusterName;
          NODE_MASTER = "false";
          NODE_INGEST = "false";
          NODE_DATA = "false";
          HTTP_ENABLE = "true";
          ES_JAVA_OPTS="-Xms${toString (cfg.clientnodes.memory * 3 / 4)}m -Xmx${toString (cfg.clientnodes.memory * 3 / 4)}m";
        };

        requests.memory = "${toString cfg.clientnodes.memory}Mi";
        requests.cpu = cfg.clientnodes.cpu;
        limits.cpu = cfg.clientnodes.cpu;

        security.capabilities.add = ["IPC_LOCK" "SYS_RESOURCE"];
      };

      pod.volumes.storage = {
        type = "emptyDir";
        options.medium = "";
      };
    };

    kubernetes.statefulSets.elasticsearch-data = {
      serviceName = "elasticsearch-data";

      replicas = cfg.datanodes.replicas;

      dependencies = [
        "services/elasticsearch-discovery"
      ];

      pod.initContainers = [{
        name = "sysctl";
        image = "busybox";
        imagePullPolicy = "IfNotPresent";
        command = ["sysctl" "-w" "vm.max_map_count=262144"];
        security.privileged = true;
      }];

      pod.containers.es-data = {
        image = cfg.image;
        ports = [{
          name = "transport";
          port = 9300;
        }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        }];

        env = {
          NAMESPACE.fieldRef.fieldPath = "metadata.namespace";
          NODE_NAME.fieldRef.fieldPath = "metadata.name";
          CLUSTER_NAME = cfg.clusterName;
          NODE_MASTER = "false";
          NODE_INGEST = "false";
          NODE_DATA = "true";
          HTTP_ENABLE = "false";
          ES_JAVA_OPTS="-Xms${toString (cfg.datanodes.memory * 3 / 4)}m -Xmx${toString (cfg.datanodes.memory * 3 / 4)}m";
        };

        requests.memory = "${toString cfg.datanodes.memory}Mi";
        requests.cpu = cfg.datanodes.cpu;
        limits.cpu = cfg.datanodes.cpu;

        security.capabilities.add = ["IPC_LOCK" "SYS_RESOURCE"];
      };

      volumeClaimTemplates.storage = {
        annotations."volume.beta.kubernetes.io/storage-class" = cfg.datanodes.storage.class;
        size = cfg.datanodes.storage.size;
      };
    };

    kubernetes.services.elasticsearch-discovery = {
      selector.name = "elasticsearch-master";
      ports = [{
        name = "discovery";
        port = 9300;
      }];
      clusterIP = "None";
    };

    kubernetes.services.elasticsearch = {
      selector.name = "elasticsearch-client";
      ports = [{
        name = "http";
        port = 9200;
      }];
    };
  };
}
