{ config, lib, ... }:

with lib;

let
  cfg = config.services.syncthing;
in {
  options.services.syncthing = {
    enable = mkEnableOption "syncthing service";

    image = mkOption {
      description = "Image to use";
      default = "joeybaker/syncthing";
      type = types.str;
    };

    data = mkOption {
      description = "Name of the pvc to use for data";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.syncthing = {
      dependencies = ["services/syncthing" "pvc/syncthing"];
      pod.containers.syncthing = {
        image = cfg.image;
        ports = [
          { port = 31669; }
          { port = 8080; }
          { port = 21025; protocol = "UDP"; }
        ];
        mounts = [{
          name = "data";
          mountPath = "/srv/data";
        } {
          name = "config";
          mountPath = "/srv/config";
        }];
      };

      pod.volumes.data = {
        type = "persistentVolumeClaim";
        options.claimName = cfg.data;
      };

      pod.volumes.config = {
        type = "persistentVolumeClaim";
        options.claimName = "syncthing";
      };
    };

    kubernetes.services.syncthing.type = "NodePort";
    kubernetes.services.syncthing.ports = [
      { port = 31669; targetPort = 31669; name = "share"; nodePort = 31669; }
      { port = 8080; targetPort = 8080; name = "http"; }
      { port = 21025; targetPort = 21025; protocol = "UDP"; name = "share2"; }
    ];
    kubernetes.pvc.syncthing.size = "1G";
  };
}
