{ config, lib, ... }:

with lib;

let
  cfg = config.services.elasticsearch;
in {
  options.services.elasticsearch = {
    enable = mkEnableOption "elasticsearch service";

    image = mkOption {
      description = "Elasticsearch image to use";
      default = "docker.elastic.co/elasticsearch/elasticsearch:5.2.2";
    };

    clusterName = mkOption {
      description = "Name of the cluster";
      type = types.str;
    };

    memoryLimit = mkOption {
      description = "Memory limit in megabytes";
      default = 2048;
      type = types.int;
    };

    cpuLimit = mkOption {
      description = "CPU limit";
      default = "250m";
      type = types.str;
    };

    storageSize = mkOption {
      description = "Storage size of volume";
      default = "10G";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.elasticsearch = {
      dependencies = ["services/elasticsearch" "pvc/elasticsearch"];

      pod.annotations = {
        "pod.beta.kubernetes.io/init-containers" = ''[
        {
          "name": "sysctl",
          "image": "busybox",
          "imagePullPolicy": "IfNotPresent",
          "command": ["sysctl", "-w", "vm.max_map_count=262144"],
          "securityContext": {
            "privileged": true
          }
        },
        {
            "name": "chown",
            "image": "busybox",
            "imagePullPolicy": "IfNotPresent",
            "command": ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"],
            "volumeMounts": [
                {
                  "name": "storage",
                  "mountPath": "/usr/share/elasticsearch/data"
                }
            ]
        }
        ]'';
      };

      pod.containers.elasticsearch = {
        image = cfg.image;
        command = ["/bin/bash" "-c" ''
# bash does not support dotted env variables
          env xpack.security.enabled=false http.host=0.0.0.0 transport.host=127.0.0.1 bin/es-docker
          ''];
        ports = [{ port = 9200; }];
        mounts = [{
          name = "storage";
          mountPath = "/usr/share/elasticsearch/data";
        }];

        env = {
          ES_JAVA_OPTS="-Xms${toString (cfg.memoryLimit * 3 / 4)}m -Xmx${toString (cfg.memoryLimit * 3 / 4)}m";
        };

        requests.memory = "${toString cfg.memoryLimit}Mi";
        requests.cpu = cfg.cpuLimit;
        limits.memory = "${toString cfg.memoryLimit}Mi";
        limits.cpu = cfg.cpuLimit;

        security.capabilities.add = ["IPC_LOCK"];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "elasticsearch";
      };
    };

    kubernetes.services.elasticsearch.ports = [{ port = 9200; }];

    kubernetes.pvc.elasticsearch.size = mkDefault cfg.storageSize;
  };
}
