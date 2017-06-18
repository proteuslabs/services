{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rabbitmq;
in {
  options.services.rabbitmq = {
    enable = mkEnableOption "rabbitmq service";

    user = mkOption {
      description = "Databse user";
      type = types.nullOr types.str;
      default = null;
    };

    password = mkOption {
      description = "Database password";
      type = types.nullOr types.str;
      default = null;
    };

    vhost = mkOption {
      description = "Set default vhost name";
      type = types.nullOr types.lines;
      default = "rabbit-mq";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.rabbitmq = {
      dependencies = ["services/rabbitmq" "pvc/rabbitmq"];

      pod.containers.rabbitmq = {
        image = "rabbitmq:3-management";
        env = {
          RABBITMQ_DEFAULT_USER = cfg.user;
          RABBITMQ_DEFAULT_PASS = cfg.password;
          RABBITMQ_DEFAULT_VHOST  = cfg.vhost;
        };
        mounts = [{
          name = "storage";
          mountPath = "/var/lib/rabbitmq";
        }];
        ports = [{ port = 15672; }];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "rabbitmq";
      };
    };

    kubernetes.services.rabbitmq.ports = [
      { port = 15672; name="monitoring"; }
      { port = 5672; name="rabbitmq"; }
    ];

    kubernetes.pvc.rabbitmq = {
      name = "rabbitmq";
      size = "1G";
    };
  };
}
