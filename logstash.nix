{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.logstash;
in {
  options.services.logstash = {
    enable = mkOption {
      description = "Wheter to enable logstash";
      type = types.bool;
      default = false;
    };

    configuration = mkOption {
      description = "Logstash configuration file content";
      type = types.lines;
    };

    image = mkOption {
      description = "Name of the image";
      type = types.str;
      default = "logstash";
    };

    kind = mkOption {
      description = "Kind of ";
      default = "deployment";
      type = types.enum ["deployment" "daemonset"];
    };
  };

  config = mkIf cfg.enable {
    kubernetes."${cfg.kind}s".logstash = {
      dependencies = ["configmaps/logstash"];

      pod.containers.logstash = {
        image = cfg.image;

        command = [
          "logstash" "-f" "/config/logstash.conf"
          "--config.reload.automatic"
        ];

        requests.memory = "512Mi";
        limits.memory = "1024Mi";

        mounts = [{
          name = "config";
          mountPath = "/config";
        }];
      };

      pod.volumes.config = {
        type = "configMap";
        options.name = "logstash";
      };
    };

    kubernetes.configMaps.logstash = {
      data."logstash.conf" = cfg.configuration;
    };
  };
}
