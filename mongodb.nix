{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mongo;

  mongodConf = {
    storage.dbPath = "/data/db";
    net.port = 27017;
    replication.replSetName = cfg.replicaSet;
    security = {
      authorization = if cfg.auth.enable then "enabled" else "disabled";
    } // (optionalAttrs cfg.auth.enable {
      keyFile = "/keydir/key.txt";
    });
  };
in {
  options.services.mongo = {
    enable = mkEnableOption "mongo service";

    replicaSet = mkOption {
      description = "Name of the mongo replicaset";
      default = "rs0";
      type = types.str;
    };

    auth = {
      enable = mkEnableOption "enable mongo auth";

      adminUser = mkOption {
        description = "Mongo admin user";
        type = types.str;
      };

      adminPassword = mkOption {
        description = "Mongo admin password";
        type = types.str;
      };

      keyFile = mkOption {
        description = "Mongo keyfile";
        type = types.path;
      };
    };

    storage = {
      size = mkOption {
        description = "Mongo storage size";
        type = types.str;
        default = "10Gi";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    kubernetes.statefulSets.mongo = {
      serviceName = "mongo";

      dependencies = [
        "services/mongo"
        "configmaps/mongo"
        "serviceaccounts/mongo"
        "clusterrolebindings/mongo"
        "clusterroles/mongo"
        "poddistributionbudgets/mongo"
      ] ++ (optionals cfg.auth.enable "secrets/mongo-keyfile-secret");

      replicas = mkDefault 3;

      pod.serviceAccountName = "mongo";

      pod.containers.mongo-sidecar = {
        image = "cvallance/mongo-k8s-sidecar";
        env = {
          KUBECTL_NAMESPACE.fieldRef = {
            apiVersion = "v1";
            fieldPath = "metadata.namespace";
          };
          KUBE_NAMESPACE.fieldRef = {
            apiVersion = "v1";
            fieldPath = "metadata.namespace";
          };
          MONGO_SIDECAR_POD_LABELS = "name=mongo";
          KUBERNETES_MONGO_SERVICE_NAME = "mongo";
          MONGO_PORT = "27017";
        } // (optionalAttrs cfg.auth.enable {
          MONGODB_USERNAME = cfg.auth.adminUser;
          MONGODB_PASSWORD = cfg.auth.adminPassword;
        });
      };

      pod.containers.mongo = {
        image = "mongo:3.4";
        imagePullPolicy = "IfNotPresent";
        ports = [{
          name = "peer";
          containerPort = 27017;
        }];
        command = ["mongod" "--config=/config/mongod.conf"];
        env = optionalAttrs cfg.auth.enable {
          AUTH = "true";
          ADMIN_USER = cfg.auth.adminUser;
          ADMIN_PASSWORD = cfg.auth.adminPassword;
        };
        livenessProbe = {
          exec.command = ["mongo" "--eval" "db.adminCommand('ping')"];
          initialDelaySeconds = 30;
          timeoutSeconds = 5;
        };
        readinessProbe = {
          exec.command = ["mongo" "--eval" "db.adminCommand('ping')"];
          initialDelaySeconds = 5;
          timeoutSeconds = 1;
        };
        mounts = [{
          name = "datadir";
          mountPath = "/data/db";
        } {
          name = "config";
          mountPath = "/config";
        } {
          name = "workdir";
          mountPath = "/work-dir";
        }] ++ (optionals cfg.auth.enable {
          name = "keydir";
          mountPath = "/keydir";
          readOnly = true;
        });
      };

      pod.volumes = {
        config = {
          type = "configMap";
          options.name = "mongo";
        };
        workdir = {
          type = "emptyDir";
        };
      } // (optionalAttrs cfg.auth.enable {
        keydir = {
          type = "secret";
          options = {
            defaultMode = "0400";
            secretName = "mongo-keyfile-secret";
          };
        };
      });

      volumeClaimTemplates.datadir = {
        size = cfg.storage.size;
      };
    };

    kubernetes.services.mongo = {
      clusterIP = "None";
      ports = [{ port = 27017; }];
    };

    kubernetes.configMaps.mongo.data = {
      "mongod.conf" = builtins.toJSON mongodConf;
    };

    kubernetes.serviceAccounts.mongo = {};

    kubernetes.clusterRoleBindings.mongo = {
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "mongo";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "mongo";
        namespace = config.kubernetes.clusterRoleBindings.mongo.namespace;
      }];
    };

    kubernetes.clusterRoles.mongo = {
      rules = [{
        apiGroups = [""];
        resources = [
          "pods"
        ];
        verbs = ["get" "list" "watch"];
      }];
    };

    kubernetes.podDistributionBudgets.mongo = {
      selector.matchLabels.name = "mongo";
      minAvailable = "60%";
    };
  } (mkIf cfg.auth.enable {
    kubernetes.secrets.mongo-keyfile-secret = {
      secrets."key.txt" = cfg.keyFile;
    };
  })]);
}
