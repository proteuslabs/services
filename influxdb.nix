{ config, lib, ... }:

with lib;

let
  cfg = config.services.influxdb;
in {
  options.services.influxdb = {
    enable = mkEnableOption "influxdb service";

    adminUser = mkOption {
      description = "Name of the admin user";
      type = types.str;
      default = "admin";
    };

    adminPassword = mkOption {
      description = "Admin password";
      type = types.str;
      default = "admin";
    };

    preCreateDb = mkOption {
      description = "List of databases to pre create";
      type = types.listOf types.str;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.influxdb = {
      dependencies = ["services/influxdb" "pvc/influxdb"];
      pod.containers.influxdb = {
        image = "influxdb:1.1.0";
        ports = [
          { port = 8083; } # admin
          { port = 8086; } # http
          { port = 8086; protocol = "UDP"; } # udp
          { port = 8088; } # cluster
        ];
        mounts = [{
          name = "storage";
          mountPath = "/var/lib/influxdb";
        }];
        requests.memory = "256Mi";
        requests.cpu = "200m";
        limits.memory = "256Mi";
        limits.cpu = "200m";
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "influxdb";
      };
    };

    kubernetes.services.influxdb.ports = [
      { port = 8083; name = "admin"; }
      { port = 8086; name = "http"; }
      { port = 8086; protocol = "UDP"; name = "udp"; }
      { port = 8088; name = "cluster"; }
    ];

    kubernetes.pvc.influxdb.size = "10G";
  };
}
