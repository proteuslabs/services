{ config, lib, ... }:

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
      pod.containers.logstash = {
        image = cfg.image;
        command = ["logstash" "-e" cfg.configuration];

        requests.memory = "512Mi";
        limits.memory = "512Mi";
      };
    };
  };
}
