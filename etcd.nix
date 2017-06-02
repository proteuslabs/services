{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.etcd;
in {
  options.services.etcd = {
    enable = mkEnableOption "etcd cluster";

    version = mkOption {
      description = "Version of etcd operator to use";
      default = "v0.3.0";
      type = types.str;
    };

    volumeProvisioner = mkOption {
      description = "Volume provisioner to use";
      type = types.nullOr types.str;
      default = null;
      example = "kubernetes.io/aws-ebs";
    };

    clusters = mkOption {
      description = "Defined etcd clusters";
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
      pod.containers.etcd-operator = {
        image = "quay.io/coreos/etcd-operator:${cfg.version}";
        command =
          ["/usr/local/bin/etcd-operator"] ++
          (optionals (cfg.volumeProvisioner != null) "--pv-provisioner=${cfg.volumeProvisioner}s");
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

    kubernetes.customResources.etcd-cluster = mapAttrs (name: config: {
      kind = "Cluster";
      apiVersion = "etcd.coreos.com/v1beta1";
      extra.spec = {
        inherit (config) size version;
      };
    }) cfg.clusters;
  };
}
