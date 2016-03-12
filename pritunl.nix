{ config, lib, ... }:

with lib;

let
  cfg = config.services.pritunl;
in {
  options.services.pritunl = {
    enable = mkEnableOption "pritunl service";
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.pritunl = {
      dependencies = ["services/pritunl" "pvc/pritunl"];

      pod.containers.pritunl = {
        image = "offlinehacker/pritunl";
        env = {
          MONGO_URI = "mongodb://127.0.0.1:27017/pritunl";
        };
        security.privileged = true;
        ports = [{ port = 1194; } { port = 9700; }];
      };

      pod.containers.mongodb = {
        image = "mongo";
        mounts = [{
          name = "storage";
          mountPath = "/data/db";
        }];
        ports = [{ port = 27017; }];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "pritunl";
      };
    };

    kubernetes.services.pritunl = {
      ports = [{
        name = "openvpn";
        port = 1194;
      } {
        name = "pritunl";
        port = 443;
        targetPort = 9700;
      }];

      type = "LoadBalancer";
    };

    kubernetes.pvc.pritunl.size = "1G";
  };
}
