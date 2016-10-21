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
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.logstash = {
      dependencies = ["secrets/logstash"];

      pod.containers.logstash = {
        image = cfg.image;

        command = ["logstash" "-f" "/etc/logstash/logstash.conf" "--auto-reload"];

        requests.memory = "512Mi";
        limits.memory = "512Mi";

        mounts = [{
          name = "config";
          mountPath = "/etc/logstash";
        }];
      };

      pod.volumes.config = {
        type = "secret";
        options.secretName = "logstash";
      };
    };

    kubernetes.secrets.logstash = {
      secrets."logstash.conf" = pkgs.writeText "logstash.conf" cfg.configuration;
    };
  };
}
