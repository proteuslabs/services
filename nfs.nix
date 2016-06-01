{ config, lib, ... }:

with lib;

let
  cfg = config.services.nfs;
in {
  options.services.nfs = {
    enable = mkEnableOption "nfs service";

    image = mkOption {
      description = "NFS image to use";
      default = "gcr.io/google_containers/volume-nfs";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.nfs = {
      dependencies = ["services/nfs" "pvc/nfs"];
      pod.containers.nfs = {
        image = cfg.image;
        ports = [
          { name = "tcp"; port = 2049; protocol = "TCP"; }
          { name = "udp"; port = 2049; protocol = "UDP"; }
        ];

        mounts = [{
          name = "storage";
          mountPath = "/exports";
        }];

        security.privileged = true;
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "nfs";
      };
    };

    kubernetes.services.nfs.ports = [
      { port = 2049; targetPort = 2049; protocol = "TCP"; name = "nfs-tcp"; }
      { port = 2049; targetPort = 2049; protocol = "UDP"; name = "nfs-udp"; }
    ];
    kubernetes.pvc.nfs.size = "100G";
  };
}
