{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.telegraf;
in {
  options.services.telegraf = {
    enable = mkOption {
      description = "Wheter to enable telegraf";
      type = types.bool;
      default = false;
    };

    configuration = mkOption {
      description = "Telegraf configuration file content";
      type = types.lines;
    };

    image = mkOption {
      description = "Name of the image";
      type = types.str;
      default = "telegraf";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.telegraf = {
      dependencies = ["secrets/telegraf"];
      pod.containers.telegraf = {
        image = cfg.image;
        command = ["telegraf" "-config" "/etc/telegraf/telegraf.conf"];
        mounts = [{
          name = "config";
          mountPath = "/etc/telegraf";
        }];
      };
      pod.volumes.config = {
        type = "secret";
        options.secretName = "telegraf";
      };
    };

    kubernetes.secrets.telegraf = {
      secrets."telegraf.conf" = pkgs.writeText "telegraf.conf" cfg.configuration;
    };
  };
}
