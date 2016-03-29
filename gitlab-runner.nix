{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitlab-runner;
in {
  options.services.gitlab-runner = {
    enable = mkEnableOption "gitlab runner service";

    replicas = mkOption {
      description = "Number of replicas to run for runner";
      type = types.int;
      default = 1;
    };

    storageDriver = mkOption {
      description = "Type of docker storage driver to use";
      type = types.str;
      default = "overlay";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.pods.gitlab-runner = {
      containers.gitlab-ci-multi-runner = {
        image = "gitlab/gitlab-runner";
        mounts = [{
          name = "config";
          mountPath = "/etc/gitlab-runner";
        }];
      };

      containers.dind = {
        image = "docker:1.10-dind";
        security.privileged = true;
        args = ["--storage-driver" cfg.storageDriver];
        mounts = [{
          name = "cgroups";
          mountPath = "/sys/fs/cgroup";
        }];
      };

      volumes.config.type = "emptyDir";
      volumes.cgroups = {
        type = "hostPath";
        options.path = "/sys/fs/cgroup";
      };
    };
  };
}
