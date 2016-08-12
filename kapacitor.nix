{ config, lib, ... }:

with lib;

let
  cfg = config.services.kapacitor;
in {
  options.services.kapacitor = {
    enable = mkEnableOption "kapacitor service";

    influxdb = {
      url = mkOption {
        description = "Influxdb url";
        type = types.str;
        default = "http://influxdb:8086";
      };

      user = mkOption {
        description = "Influxdb user";
        type = types.str;
        default = "admin";
      };

      pass = mkOption {
        description = "Influxdb password";
        type = types.str;
        default = "admin";
      };
    };

    smtp = {
      enable = mkEnableOption "smtp";

      host = mkOption {
        description = "Smtp host";
        type = types.str;
      };

      port = mkOption {
        description = "Smtp port";
        type = types.int;
      };

      user = mkOption {
        description = "Smtp username";
        type = types.str;
      };

      pass = mkOption {
        description = "Smtp password";
        type = types.str;
      };

      from = mkOption {
        description = "Send from address";
        type = types.str;
      };
    };

    hipchat = {
      enable = mkEnableOption "hipchat";

      url = mkOption {
        description = "Hipchat subdomain";
        type = types.str;
      };

      room = mkOption {
        description = "Hipchat room";
        type = types.str;
      };

      token = mkOption {
        description = "Hipchat token";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.kapacitor = {
      dependencies = ["services/kapacitor" "pvc/kapacitor"];
      pod.containers.kapacitor = {
        image = "kapacitor";
        env = mkMerge [{
          KAPACITOR_INFLUXDB_0_URLS_0 = cfg.influxdb.url;
          KAPACITOR_INFLUXDB_0_USERNAME = cfg.influxdb.user;
          KAPACITOR_INFLUXDB_0_PASSWORD = cfg.influxdb.pass;
        } (mkIf cfg.smtp.enable {
          KAPACITOR_SMTP_ENABLED = "true";
          KAPACITOR_SMTP_HOST = cfg.smtp.host;
          KAPACITOR_SMTP_PORT = toString cfg.smtp.port;
          KAPACITOR_SMTP_USERNAME = cfg.smtp.user;
          KAPACITOR_SMTP_PASSWORD = cfg.smtp.pass;
          KAPACITOR_SMTP_FROM = cfg.smtp.from;
        })];
        ports = [{ port = 9092; }];
        mounts = [{
          name = "storage";
          mountPath = "/var/lib/kapacitor";
        }];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "kapacitor";
      };
    };

    kubernetes.services.kapacitor.ports = [{ port = 9092; }];

    kubernetes.pvc.kapacitor.size = "1G";
  };
}
