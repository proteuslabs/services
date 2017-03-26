{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mongodb;
in {
  options.services.mongodb = {
    enable = mkEnableOption "mongodb service";
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.mongodb = {
      dependencies = ["services/mongodb" "pvc/mongodb"];

      pod.containers.mongodb = {
        image = "mongo";
        mounts = [{
          name = "storage";
          mountPath = "/data/db";
        }];
        ports = [{ port = 27017; }];
        requests.memory = "128Mi";
        requests.cpu = "100m";
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "mongodb";
      };
    };

    kubernetes.services.mongodb.ports = [{ port = 27017; }];

    kubernetes.pvc.mongodb = {
      name = "mongodb";
      size = mkDefault "10G";
    };
  };
}
