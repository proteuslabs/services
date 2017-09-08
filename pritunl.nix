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

    mongodbUri = mkOption {
      description = "URI for mongodb database";
      type = types.str;
      default = "mongodb://mongodb/pritunl";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.pritunl = {
      dependencies = ["services/pritunl" "pvc/pritunl" "secrets/pritunl-firewall"];

      pod.containers.pritunl = {
        image = cfg.image;
        env = {
          MONGO_URI = cfg.mongodbUri;
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
        name = "pritunl-http";
        port = 80;
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
