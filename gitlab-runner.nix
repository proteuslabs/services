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
      default = "overlay";
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
      default = null;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers = listToAttrs (mapAttrsFlatten (name: token:
      nameValuePair "gitlab-runner-${name}" {
        dependencies = ["secrets/gitlab-runner-${name}"];

        pod.nodeSelector = cfg.nodeSelector;

        pod.containers.gitlab-ci-multi-runner = {
          image = "gitlab/gitlab-runner";
          mounts = [{
            name = "config";
            mountPath = "/etc/gitlab-runner";
          }];
        };

        pod.containers.dind = {
          image = "docker:1.12-dind";
          security.privileged = true;
          args = ["--storage-driver" cfg.storageDriver];
          requests.memory = "1024Mi";
          requests.cpu = "250m";
          limits.memory = "1024Mi";
          mounts = [{
            name = "cgroups";
            mountPath = "/sys/fs/cgroup";
          }];
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
  };
}
