{ config, lib, ... }:

with lib;

let
  cfg = config.services.grafana;
in {
  options.services.grafana = {
    enable = mkEnableOption "grafana service";

    version = mkOption {
      description = "Version of grafana to use";
      default = "4.2.0";
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
        default = null;
        type = types.enum [null "sqlite3" "mysql" "postgres"];
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

    enableWatcher = mkOption {
      description = "Whether to enable watcher";
      type = types.bool;
      default = (length (attrNames cfg.dashboards)) > 0;
    };

    dashboards = mkOption {
      description = "Attribute set of grafana resources to deploy";
      default = {};
    };

    extraConfig = mkOption {
      description = "Grafana extra configuration options";
      type = types.attrsOf types.str;
      default = {};
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    kubernetes.deployments.grafana = {
      dependencies = ["services/grafana"];
      pod.containers.grafana = {
        image = "grafana/grafana:${cfg.version}";
        env = {
          GF_SERVER_ROOT_URL = cfg.rootUrl;
          GF_SECURITY_ADMIN_USER = "admin";
          GF_SECURITY_ADMIN_PASSWORD = cfg.adminPassword;
          GF_PATHS_DATA = "/data";
          GF_USERS_ALLOW_SIGN_UP = "false";
          GF_AUTH_BASIC_ENABLED = "true";
          GF_AUTH_ANONYMOUS_ENABLED = "true";
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
        requests = {
          memory = "100Mi";
          cpu = "100m";
        };
        limits = {
          memory = "200Mi";
          cpu = "200m";
        };

        readinessProbe.httpGet = {
          path = "/login";
          port = 3000;
        };
      };
    };

    kubernetes.services.grafana.ports = [{ port = 80; targetPort = 3000; }];
  } (mkIf (cfg.db.type != "sqlite3") {
    kubernetes.deployments.grafana.pod.volumes.storage = {
      type = "emptyDir";
    };
  }) (mkIf (cfg.db.type == "sqlite3") {
    kubernetes.deployments.grafana = {
      dependencies = ["pvc/grafana"];
      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "grafana";
      };
    };
    kubernetes.pvc.grafana.size = "1G";
  }) (mkIf cfg.enableWatcher {
    kubernetes.deployments.grafana = {
      dependencies = ["configmaps/grafana-dashboards"];
      pod.containers.watcher = {
        image = "quay.io/coreos/grafana-watcher:v0.0.4";
        args = [
          "--watch-dir=/var/grafana-dashboards"
          "--grafana-url=http://localhost:3000"
        ];
        env = {
          GRAFANA_USER = "admin";
          GRAFANA_PASSWORD = cfg.adminPassword;
        };
        requests = {
          memory = "16Mi";
          cpu = "50m";
        };
        limits = {
          memory = "32Mi";
          cpu = "100m";
        };
        mounts = [{
          name = "dashboards";
          mountPath = "/var/grafana-dashboards";
        }];
      };
      pod.volumes.dashboards = {
        type = "configMap";
        options.name = "grafana-dashboards";
      };
    };

    kubernetes.configMaps.grafana-dashboards.data = mapAttrs (name: value:
      if isAttrs value then builtins.toJSON value
      else builtins.readFile value
    ) cfg.dashboards;
  })]);
}
