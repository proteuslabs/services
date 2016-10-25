{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubelog;
in {
  options.services.kubelog = {
    enable = mkOption {
      description = "Wheter to kubernetes logging";
      type = types.bool;
      default = false;
    };

    namespaces = mkOption {
      description = "List of namespaces to log";
      type = types.listOf types.str;
      default = ["kube-system"];
    };

    containers = mkOption {
      description = "List of containers to collect logs from (all by default)";
      type = types.nullOr (types.listOf types.str);
      default = null;
    };

    outputConfig = mkOption {
      description = "Logstash output config";
      type = types.lines;
    };
  };

  config = mkIf cfg.enable {
    services.logstash = {
      enable = true;

      image = "gatehub/logstash";
      kind = "daemonset";

      configuration = ''
        input {
          file {
            path => "/var/log/containers/*.log"
            sincedb_path => "/data/sincedb"
          }
        }

        filter {
          kubernetes {}

          if [kubernetes][namespace] not in [${concatMapStringsSep ","
          (n: ''"${n}"'')cfg.namespaces}] {
            drop { }
          }

          ${optionalString (cfg.containers != null) ''
          if [kubernetes][container_name] not in [${concatStringsSep ","
            cfg.containers}] {
            drop {}
          }
          ''}

          json {
            source => "message"
          }

          mutate {
            remove_field => "message"
          }

          json {
            source => "log"
          }
        }

        output {
          ${cfg.outputConfig}
        }
      '';
    };

    kubernetes.daemonsets.logstash.pod = {
      containers.logstash.mounts = [{
        name = "log-containers";
        mountPath = "/var/log/containers";
      } {
        name = "docker-containers";
        mountPath = "/var/lib/docker/containers";
      } {
        name = "data";
        mountPath = "/data";
      }];

      volumes.log-containers = {
        type = "hostPath";
        options.path = "/var/log/containers";
      };

      volumes.docker-containers = {
        type = "hostPath";
        options.path = "/var/lib/docker/containers";
      };

      volumes.data = {
        type = "hostPath";
        options.path = "/var/log/kubernetes/logstash";
      };
    };
  };
}
