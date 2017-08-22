{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitlab-runner;

  genConfig = name: token: {
    concurrent = cfg.concurrent;
    runners = [{
      inherit name token;
      url = cfg.gitlabUrl;
      environment = mapAttrsToList (n: v: "${n}=${v}") cfg.environment;
      executor = "docker";
      docker = {
        host = "tcp://localhost:2375";
        privileged = cfg.privileged;
        volumes = [
          "/cache"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/var/run/secrets/kubernetes.io/serviceaccount:/var/run/secrets/kubernetes.io/serviceaccount"
        ];
        allowed_images = cfg.allowedImages;
        allowed_services = cfg.allowedServices;
      };
    }];
  };
in {
  options.services.gitlab-runner = {
    enable = mkEnableOption "gitlab runner service";

    gitlabUrl = mkOption {
      description = "Gitlab url";
      type = types.str;
      default = "http://gitlab.dev.svc.cluster.local/ci";
    };

    environment = mkOption {
      description = "Environment variables to set during the build";
      type = types.attrsOf types.str;
      default = {};
    };

    image = mkOption {
      description = "Default image to use";
      type = types.str;
      default = "node:4.2";
    };

    privileged = mkOption {
      description = "Whether to run runner as privileged";
      type = types.bool;
      default = false;
    };

    allowedImages = mkOption {
      description = "List of image to allow";
      type = types.listOf types.str;
      default = [];
    };

    allowedServices = mkOption {
      description = "List of services to allow";
      type = types.listOf types.str;
      default = [];
    };

    storageDriver = mkOption {
      description = "Type of docker storage driver to use";
      type = types.str;
      default = "overlay2";
    };

    runners = mkOption {
      description = "List of runners to deploy";
      type = types.attrsOf types.str;
      example = {"gitlab-6ugut" = "<token>";};
    };

    concurrent = mkOption {
      description = "Number of concurrent jobs to run";
      type = types.int;
      default = 1;
    };

    nodeSelector = mkOption {
      description = "Service node selector";
      default = {};
    };

    roleBindingNamespace = mkOption {
      description = "Role binding namespace";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments = listToAttrs (mapAttrsFlatten (name: token:
      nameValuePair "gitlab-runner-${name}" {
        dependencies = [
          "secrets/gitlab-runner-${name}"
          "pvc/gitlab-runner-${name}-dind"
          "rolebindings/gitlab-runner"
          "roles/gitlab-runner"
          "serviceaccounts/gitlab-runner"
        ];

        pod.nodeSelector = cfg.nodeSelector;
        pod.serviceAccountName = "gitlab-runner";

        pod.containers.gitlab-ci-multi-runner = {
          image = "gitlab/gitlab-runner:v1.9.5";
          mounts = [{
            name = "config";
            mountPath = "/etc/gitlab-runner";
          }];
        };

        pod.containers.dind = {
          image = "docker:1.13-dind";
          args = ["--storage-driver" cfg.storageDriver];
          security.privileged = true;
          requests.memory = "1024Mi";
          requests.cpu = "500m";
          limits.memory = "1024Mi";
          mounts = [{
            name = "cgroups";
            mountPath = "/sys/fs/cgroup";
          } {
            name = "storage";
            mountPath = "/var/lib/docker";
          }];
        };

        pod.volumes.storage = {
          type = "persistentVolumeClaim";
          options.claimName = "gitlab-runner-${name}-dind";
        };

        pod.volumes.cgroups = {
          type = "hostPath";
          options.path = "/sys/fs/cgroup";
        };

        pod.volumes.config = {
          type = "secret";
          options.secretName = "gitlab-runner-${name}";
        };
    }) cfg.runners);

    kubernetes.pvc = listToAttrs (mapAttrsFlatten (name: token:
      nameValuePair "gitlab-runner-${name}-dind"{
    size = "100G";
      annotations = {
          "volume.beta.kubernetes.io/storage-class" = "default";
        };
      }
    ) cfg.runners);

    kubernetes.secrets = listToAttrs (mapAttrsFlatten (name: token:
      nameValuePair "gitlab-runner-${name}" {
        secrets."config.toml" = pkgs.runCommand "config.toml" {
          buildInputs = [pkgs.remarshal];
        } ''
          remarshal -if json -of toml -i ${
            pkgs.writeText "config.json" (builtins.toJSON (genConfig name token))
          } > $out
        '';
      }
    ) cfg.runners);

    kubernetes.roleBindings.gitlab-runner = {
      namespace = cfg.roleBindingNamespace;
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "Role";
        name = "gitlab-runner";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "gitlab-runner";
        namespace = config.kubernetes.defaultNamespace;
      }];
    };

    kubernetes.roles.gitlab-runner = {
      namespace = cfg.roleBindingNamespace;
      rules = [{
        apiGroups = [""];
        resources = [
          "deployments"
        ];
        verbs = ["patch"];
      } {
        apiGroups = ["extensions" "apps"];
        resources = [
          "deployments"
        ];
        verbs = ["*"];
      }];
    };

    kubernetes.serviceAccounts.gitlab-runner = {};
  };
}
