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

    ignoredMountPoints = mkOption {
      description = "Regex for ignored mount points";
      type = types.str;

      # this is ugly negative regex that ignores everyting except /host/.*
      default = "^/(([h][^o]?(/.+)?)|([h][o][^s]?(/.+)?)|([h][o][s][^t]?(/.+)?)|([^h]?[^o]?[^s]?[^t]?(/.+)?)|([^h][^o][^s][^t](/.+)?))$";
    };

    ignoredFsTypes = mkOption {
      description = "Regex of ignored filesystem types";
      type = types.str;
      default = "^(proc|sys|cgroup|securityfs|debugfs|autofs|tmpfs|sysfs|binfmt_misc|devpts|overlay|mqueue|nsfs|ramfs|hugetlbfs|pstore)$";
    };

    extraPaths = mkOption {
      description = "Extra node-exporter host paths";
      default = {};
      type = types.attrsOf (types.submodule ({name, config, ...}: {
        options = {
          hostPath = mkOption {
            description = "Host path to mount";
            type = types.path;
          };

          mountPath = mkOption {
            description = "Path where to mount";
            type = types.path;
            default = "/host/${name}";
          };
        };
      }));
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
          "--collector.filesystem.ignored-mount-points=${cfg.ignoredMountPoints}"
          "--collector.filesystem.ignored-fs-types=${cfg.ignoredFsTypes}"
        ] ++ cfg.extraArgs;
        ports = [{
          port = 9100;
          hostPort = 9100;
        }];
        livenessProbe = {
          httpGet = {
            path = "/metrics";
            port = 9100;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 1;
        };
        mounts = [{
          name = "proc";
          mountPath = "/host/proc";
          readOnly = true;
        } {
          name = "sys";
          mountPath = "/host/sys";
          readOnly = true;
        }] ++ (mapAttrsToList (name: path: {
          inherit name;
          inherit (path) mountPath;
          readOnly = true;
        }) cfg.extraPaths);
      };

      #pod.hostNetwork = true;
      pod.hostPID = true;

      pod.volumes = {
        proc = {
          type = "hostPath";
          options.path = "/proc";
        };

        sys = {
          type = "hostPath";
          options.path = "/sys";
        };
      } // (mapAttrs (name: path: {
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
