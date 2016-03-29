{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mediawiki;
in {
  options.services.mediawiki = {
    enable = mkEnableOption "mediawiki service";

    image = mkOption {
      description = "Mediawiki image to use";
      default = "xtruder/mediawiki:1.26-full";
      type = types.str;
    };

    url = mkOption {
      description = "Url for mediawiki service";
      type = types.str;
    };

    siteName = mkOption {
      description = "Mediawiki site name";
      type = types.str;
      default = "Company internal Wiki";
    };

    adminUser = mkOption {
      description = "Mediawiki admin user";
      type = types.str;
      default = "admin";
    };

    adminPassword = mkOption {
      description = "Mediawiki admin password";
      type = types.str;
    };

    customConfig = mkOption {
      description = "Mediawiki custom config";
      type = types.str;
      default = "";
    };

    db = {
      type = mkOption {
        description = "Database type";
        type = types.enum ["mysql" "postgres"];
        default = "mysql";
      };

      name = mkOption {
        description = "Database name";
        type = types.str;
        default = "mediawiki";
      };

      host = mkOption {
        description = "Database host";
        type = types.str;
        default = "mysql";
      };

      port = mkOption {
        description = "Database port";
        type = types.int;
        default = 3306;
      };

      user = mkOption {
        description = "Database user";
        type = types.str;
        default = "mediawiki";
      };

      pass = mkOption {
        description = "Database password";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.mediawiki = {
      dependencies = ["services/mediawiki" "pvc/mediawiki" "secrets/mediawiki"];

      pod.containers.parsoid = {
        image = "motiz88/parsoid";

        env = {
          MW_URL = http://127.0.0.1;
          PORT = "8000";
        };

        ports = [{ port = 8000; }];
      };

      pod.containers.mediawiki = {
        image = "offlinehacker/mediawiki:latest";

        mounts = [{
          name = "data";
          mountPath = "/data";
        } {
          name = "config";
          mountPath = "/config";
        }];

        env = {
          MEDIAWIKI_SITE_SERVER = cfg.url;
          MEDIAWIKI_SITE_NAME = cfg.siteName;
          MEDIAWIKI_ADMIN_USER = cfg.adminUser;
          MEDIAWIKI_ADMIN_PASS = cfg.adminPassword;
          MEDIAWIKI_DB_TYPE = cfg.db.type;
          MEDIAWIKI_DB_HOST = cfg.db.host;
          MEDIAWIKI_DB_PORT = toString cfg.db.port;
          MEDIAWIKI_DB_USER = cfg.db.user;
          MEDIAWIKI_DB_PASSWORD = cfg.db.pass;
          MEDIAWIKI_DB_NAME = cfg.db.name;
          MEDIAWIKI_UPDATE = true;
        };

        postStart.command = "cp /config/settings.php /data/CustomSettings.php && echo ok";

        ports = [{ port = 80; } { port = 443; }];
      };

      pod.volumes.data = {
        type = "persistentVolumeClaim";
        options.claimName = "mediawiki";
      };

      pod.volumes.config = {
        type = "secret";
        options.secretName = "mediawiki";
      };
    };

    kubernetes.services.mediawiki.ports = [{
      name = "http";
      port = 80;
    } {
      name = "https";
      port = 443;
    } {
      name = "parsoid";
      port = 8000;
    }];
    kubernetes.pvc.mediawiki.size = "10G";

    kubernetes.secrets.mediawiki.secrets = {
      "settings.php" = (pkgs.writeText
        "CustomSettings.php" (
          ''<?php
          ${cfg.customConfig}
          ?>''
        )
      );
    };
  };
}
