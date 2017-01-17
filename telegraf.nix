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
      type = types.attrs;
    };

    image = mkOption {
      description = "Name of the image";
      type = types.str;
      default = "telegraf:1.2.0-rc1";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.telegraf = {
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
       secrets."telegraf.conf" = pkgs.runCommand "telegraf.toml" {
          buildInputs = [pkgs.remarshal];
        } ''
          remarshal -if json -of toml -i ${
            pkgs.writeText "config.json" (builtins.toJSON cfg.configuration)
          } > $out
        '';
     };
  };
}
