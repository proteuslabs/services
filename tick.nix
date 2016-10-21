{ config, lib, ... }:

with lib;

let
  cfg = config.services.tick;
in {
  options.services.tick = {
    enable = mkEnableOption "tick stack";

    influxdbPass = mkOption {
      description = "Influxdb admin password";
      type = types.str;
      default = "admin";
    };
  };

  config = mkIf cfg.enable {
    services.influxdb =  {
      enable = true;
      adminUser = "admin";
      adminPassword = cfg.influxdbPass;
      preCreateDb = [ "servers" "monitors" "misc" ] ;
    };

    services.kapacitor = {
      enable = true;
      influxdb.url = "http://influxdb:8086";
      influxdb.pass = cfg.influxdbPass;
      smtp = {
        enable = true;
        host = mkDefault config.globals.smtp.host;
        user = mkDefault config.globals.smtp.user;
        pass = mkDefault config.globals.smtp.pass;
        from = mkDefault config.globals.smtp.from;
        to = "kristina@gatehub.net";
        port = 465;
      };
    };

    services.grafana = {
      enable = true;
      rootUrl = "http://grafana.metrics.${config.globals.internalDomain}";
    };
  };
}
