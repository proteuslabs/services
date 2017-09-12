{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.etcd;
in {
  options.services.etcd = {
    enable = mkEnableOption "etcd cluster";

    version = mkOption {
      description = "Version of etcd operator to use";
      default = "v0.5.1";
      type = types.str;
    };

    volumeProvisioner = mkOption {
      description = "Volume provisioner to use";
      type = types.nullOr types.str;
      default = null;
      example = "kubernetes.io/aws-ebs";
    };

    namespace = mkOption {
      description = "Namespace to use";
      type = types.str;
      default = config.kubernetes.defaultNamespace;
    };

    clusters = mkOption {
      description = "Defined etcd clusters";
      default = {};
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          size = mkOption {
            description = "Cluster size";
            type = types.int;
            default = 3;
          };

          version = mkOption {
            description = "etcd version to deploy";
            type = types.str;
            default = "3.1.8";
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.etcd-operator = {
      dependencies = [
        "customresourcedefinitions/etcdclusters"
        "clusterroles/etcd-operator"
        "clusterrolebindings/etcd-operator"
        "serviceaccounts/etcd-operator"
      ];

      pod.serviceAccountName = "etcd-operator";
      pod.containers.etcd-operator = {
        image = "quay.io/coreos/etcd-operator:${cfg.version}";
        command =
          ["/usr/local/bin/etcd-operator"] ++
          (optionals (cfg.volumeProvisioner != null) ["--pv-provisioner=${cfg.volumeProvisioner}"]);
        env = {
          MY_POD_NAMESPACE = {
            fieldRef.fieldPath = "metadata.namespace";
          };
          MY_POD_NAME = {
            fieldRef.fieldPath = "metadata.name";
          };
        };
        requests.memory = "128Mi";
      };
    };

    kubernetes.clusterRoles.etcd-operator.rules = [{
      apiGroups = ["etcd.database.coreos.com"];
      resources = ["etcdclusters"];
      verbs = ["*"];
    } {
      apiGroups = ["apiextensions.k8s.io"];
      resources = ["customresourcedefinitions"];
      verbs = ["*"];
    } {
      apiGroups = ["storage.k8s.io"];
      resources = ["storageclasses"];
      verbs = ["*"];
    } {
      apiGroups = [""];
      resources = ["pods" "services" "endpoints" "persistentvolumeclaims" "events"];
      verbs = ["*"];
    } {
      apiGroups = ["apps"];
      resources = ["deployments"];
      verbs = ["*"];
    }];

    kubernetes.clusterRoleBindings.etcd-operator = {
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "etcd-operator";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "etcd-operator";
        namespace = cfg.namespace;
      }];
    };

    kubernetes.serviceAccounts.etcd-operator = {};

    kubernetes.customResourceDefinitions.etcdclusters = {
      group = "etcd.database.coreos.com";
      version = "v1beta2";
      names = {
        plural = "etcdclusters";
        kind = "EtcdCluster";
        shortNames = ["etcd"];
      };
    };

    kubernetes.customResources.etcd-cluster = mapAttrs (name: config: {
      kind = "Cluster";
      apiVersion = "etcd.coreos.com/v1beta1";
      extra.spec = {
        inherit (config) size version;
      };
    }) cfg.clusters;
  };
}
