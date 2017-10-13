{ config, lib, ... }:

with lib;

let
  cfg = config.services.redis;
in {
  options.services.redis = {
    enable = mkEnableOption "redis service";

    password = mkOption {
      description = "Auth password";
      type = types.nullOr types.str;
      default = null;
    };

    persistent = mkOption {
      description = "Whether to persist data";
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable (mkMerge [
  {
    kubernetes.deployments.redis = {
      dependencies = ["services/redis"];

      pod.containers.redis = {
        image = "redis";
        args = "redis-server --appendonly yes ${optionalString (cfg.password != null) "--requirepass ${cfg.password}"}";
        mounts = mkIf cfg.persistent [{
          name = "storage";
          mountPath = "/data";
        }];
        ports = [{ port = 6379; }];
        requests.memory = "128Mi";
        requests.cpu = "50m";
      };
    };

    kubernetes.services.redis.ports = [{ port = 6379; }];
  } (mkIf cfg.persistent {
    kubernetes.deployments.redis = {
      dependencies = ["pvc/redis"];

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "redis";
      };
    };

    kubernetes.pvc.redis.size = "1G";
  })]);
}
