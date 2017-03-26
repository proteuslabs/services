{ config, lib, ... }:

with lib;

let
  cfg = config.services.grafana;
in {
  options.services.grafana = {
    enable = mkEnableOption "grafana service";

    version = mkOption {
      description = "Version of grafana to use";
      default = "4.1.0-beta1";
      type = types.str;
    };

    rootUrl = mkOption {
      description = "Grafana root url";
      type = types.str;
    };

    adminPassword = mkOption {
      description = "Grafana admin password";
      type = types.str;
      default = "admin";
    };

    db = {
      type = mkOption {
        description = "Database type";
        default = "sqlite3";
        type = types.enum ["sqlite3" "mysql" "postgres"];
      };

      path = mkOption {
        description = "Database path";
        type = types.nullOr types.str;
        default = null; 
      };

      host = mkOption {
        description = "Database host";
        type = types.nullOr types.str;
        default = null;
      };

      name = mkOption {
        description = "Database name";
        type = types.nullOr types.str;
        default = null;
      };

      user = mkOption {
        description = "Database user";
        type = types.nullOr types.str;
        default = null;
      };

      password = mkOption {
        description = "Database password";
        type = types.nullOr types.str;
        default = null;
      };
    };

    extraConfig = mkOption {
      description = "Grafana extra configuration options";
      type = types.attrsOf types.str;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.grafana = {
      dependencies = ["services/grafana" "pvc/grafana"];
      pod.containers.grafana = {
        image = "grafana/grafana:${cfg.version}";
        env = {
          GF_SERVER_ROOT_URL = cfg.rootUrl;
          GF_SECURITY_ADMIN_PASSWORD = cfg.adminPassword;
          GF_PATHS_DATA = "/data";
          GF_USERS_ALLOW_SIGN_UP = "false";
          GF_DATABASE_TYPE = cfg.db.type;
          GF_DATABASE_PATH = cfg.db.path;
          GF_DATABASE_HOST = cfg.db.host;
          GF_DATABASE_NAME = cfg.db.name;
          GF_DATABASE_USER = cfg.db.user;
          GF_DATABASE_PASSWORD = cfg.db.password;
        } // (mapAttrs' (name: val: nameValuePair ("GF_" + name) val) cfg.extraConfig);
        ports = [{ port = 3000; }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        }];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "grafana";
      };
    };

    kubernetes.services.grafana.ports = [{ port = 80; targetPort = 3000; }];
    kubernetes.pvc.grafana.size = "1G";
  };
}
