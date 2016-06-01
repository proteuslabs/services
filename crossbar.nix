{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.crossbar;

  configuration = {
    controller = {};
    workers = [{
      type = "router";
      realms = [{
        name = "realm1";
        roles = [{
          name = "anonymous";
          permissions = [{
            uri = "*";
            publish = "*";
            subscribe = true;
            call = true;
            register = true;
          }];
        }];
      }];
      transports = [{
        type = "web";
        endpoint = {
          type = "tcp";
          port = 8000;
        };
        paths = {
          "/" = {
            type = "static";
            directory = "..";
          };
          ws.type = "websocket";
        };
      }];
    }];
  } //cfg.extraConfig;
in {
  options.services.crossbar = {
    enable = mkEnableOption "crossbar service";

    extraConfig = mkOption {
      description = "Crossbar extra configuration";
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.crossbar = {
      dependencies = ["services/crossbar" "secrets/crossbar"];
      pod.containers.crossbar = {
        image = "thehq/crossbar";
        ports = [{ port = 8000; }];
        mounts = [{
          name = "crossbar";
          mountPath = "/.crossbar";
        }];
      };

      pod.volumes.crossbar = {
        type = "secret";
        options.secretName = "crossbar";
      };
    };

    kubernetes.secrets.crossbar = {
      secrets."config.json" = pkgs.writeText "config.json"
        (builtins.toJSON configuration);
    };

    kubernetes.services.crossbar.ports = [{ port = 8000; }];
  };
}
