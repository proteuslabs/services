{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mysql;
in {
  options.services.mysql = {
    enable = mkEnableOption "mysql service";

    rootPassword = mkOption {
      description = "Root password";
      type = types.str;
    };

    database = mkOption {
      description = "Database to pre create";
      type = types.nullOr types.str;
      default = null;
    };

    args = mkOption {
      description = "List of mysqld arguments";
      type = types.listOf types.str;
      default = [];
    };

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

    sql = mkOption {
      description = "Initial sql file";
      type = types.nullOr types.lines;
      default = null;
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    kubernetes.controllers.mysql = {
      dependencies = ["services/mysql" "pvc/mysql"];

      pod.containers.mysql = {
        image = "mysql:5.6";
        env = {
          MYSQL_ROOT_PASSWORD = cfg.rootPassword;
          MYSQL_DATABASE = mkIf (cfg.database != null) cfg.database;
          MYSQL_USER = mkIf (cfg.user != null) cfg.user;
          MYSQL_PASSWORD = mkIf (cfg.password != null) cfg.password;
        };
        mounts = [{
          name = "storage";
          mountPath = "/var/lib/mysql";
        }];
        ports = [{ port = 3306; }];
        requests.memory = "128Mi";
        requests.cpu = "250m";
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "mysql";
      };
    };

    kubernetes.services.mysql.ports = [{ port = 3306; }];

    kubernetes.pvc.mysql = {
      name = "mysql";
      size = "1G";
    };
  } (mkIf (cfg.sql != null) {
    kubernetes.controllers.mysql = {
      dependencies = ["secrets/mysql-init"];

      pod.containers.mysql = {
        mounts = [{
          name = "mysql-init";
          mountPath = "/docker-entrypoint-initdb.d";
        }];
        args = ["mysqld"] ++ cfg.args;
      };

      pod.volumes.mysql-init = {
        type = "secret";
        options.secretName = "mysql-init";
      };
    };

    kubernetes.secrets.mysql-init = {
      secrets."init.sql" = pkgs.writeText "init.sql" cfg.sql;
    };
  })]);
}
