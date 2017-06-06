{ config, lib, ... }:

with lib;

let
  cfg = config.services.prometheus-node-exporter;
in {
  options.services.prometheus-node-exporter = {
    enable = mkEnableOption "kubernetes prometheus node exporter";

    version = mkOption {
      description = "Version of image to use";
      default = "v0.13.0";
      type = types.str;
    };

    extraPaths = mkOption {
      description = "Extra node-exporter host paths";
      default = {};
      type = types.attrsOf (types.submodule {
        hostPath = mkOption {
          description = "Host path to mount";
          type = types.path;
        };

        mountPath = mkOption {
          description = "Path where to mount";
          type = types.path;
        };

        readOnly = mkOption {
          description = "Whether to mount read only";
          type = types.bool;
          default = true;
        };
      });
    };

    extraArgs = mkOption {
      description = "Prometheus node exporter extra arguments";
      type = types.listOf types.str;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    kubernetes.daemonsets.prometheus-node-exporter = {
      dependencies = [
        "services/prometheus-node-exporter"
      ];
      pod.containers.node-exporter = {
        image = "prom/node-exporter:${cfg.version}";
        args = [
          "--collector.procfs=/host/proc"
          "--collector.sysfs=/host/sys"
        ] ++ cfg.extraArgs;
        ports = [{
          port = 9100;
          #hostPort = 9100;
        }];
        #requests = {
          #memory = "30Mi";
          #cpu = "100m";
        #};
        #limits = {
          #memory = "50Mi";
          #cpu = "200m";
        #};
        mounts = [{
          name = "proc";
          mountPath = "/host/proc";
          #readOnly = true;
        } {
          name = "proc";
          mountPath = "/host/sys";
          #readOnly = true;
        }] ++ (mapAttrsToList (path: name: {
          inherit (path) name hostPath mountPath readOnly;
        }) cfg.extraPaths);
      };

      pod.volumes = {
        proc = {
          type = "hostPath";
          options.path = "/proc";
        };

        sys = {
          type = "hostPath";
          options.path = "/sys";
        };
      } // (mapAttrs (path: name: {
        type = "hostPath";
        options.path = path.hostPath;
      }) cfg.extraPaths);
    };

    kubernetes.services.prometheus-node-exporter = {
      annotations."prometheus.io/scrape" = "true";
      ports = [{ port = 9100; }];
    };
  };
}
