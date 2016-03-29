{ config, lib, ... }:

with lib;

let
  cfg = config.services.grafana;
in {
  options.services.grafana = {
    enable = mkEnableOption "grafana service";

    version = mkOption {
      description = "Version of grafana to use";
      default = "2.6.0";
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

    extraConfig = mkOption {
      description = "Grafana extra configuration options";
      type = types.attrsOf types.str;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.grafana = {
      dependencies = ["services/grafana" "pvc/grafana"];
      pod.containers.grafana = {
        image = "grafana/grafana:${cfg.version}";
        env = {
          GF_SERVER_ROOT_URL = cfg.rootUrl;
          GF_SECURITY_ADMIN_PASSWORD = cfg.adminPassword;
          GF_PATHS_DATA = "/data";
          GF_USERS_ALLOW_SIGN_UP = "false";
        } // (mapAttrs' (name: val: nameValuePair "GF_" + name val) cfg.extraConfig);
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
