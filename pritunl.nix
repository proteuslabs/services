{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pritunl;
in {
  options.services.pritunl = {
    enable = mkEnableOption "pritunl service";
    
    image = mkOption {
      description = "Pritunl image to use";
      default = "offlinehacker/pritunl:new";
      type = types.str;
    };

    firewall = mkOption {
      description = "Firewall configuration rules";
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.pritunl = {
      dependencies = ["services/pritunl" "pvc/pritunl" "secrets/pritunl-firewall"];

      pod.containers.pritunl = {
        image = cfg.image;
        env = {
          MONGO_URI = "mongodb://127.0.0.1:27017/pritunl";
          PRITUNL_FIREWALL_CONFIG_PATH = "/etc/pritunl/rules.json";
        };
        security.privileged = true;
        ports = [{ port = 1194; } { port = 80; } { port = 443; }];
        requests.memory = "128Mi";
        requests.cpu = "50m";
        mounts = [{
          name = "firewall";
          mountPath = "/etc/pritunl";
        }];
      };

      pod.containers.mongodb = {
        image = "mongo";
        mounts = [{
          name = "storage";
          mountPath = "/data/db";
        }];
        ports = [{ port = 27017; }];
        requests.memory = "128Mi";
        requests.cpu = "50m";
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "pritunl";
      };

      pod.volumes.firewall = {
        type = "secret";
        options.secretName = "pritunl-firewall";
      };
    };

    kubernetes.services.pritunl = {
      ports = [{
        name = "pritunl";
        port = 443;
      } {
        name = "openvpn";
        port = 1194;
      }];

      type = "LoadBalancer";
    };

    kubernetes.secrets.pritunl-firewall = {
      secrets."rules.json" = pkgs.writeText "rules.json" (builtins.toJSON cfg.firewall);
    };

    kubernetes.pvc.pritunl.size = "1G";
  };
}
