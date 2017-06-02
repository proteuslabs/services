{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wikibase-query-service;
in {
  options.services.wikibase-query-service = {
    enable = mkEnableOption "mediawiki query service";
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.wikibase-query-service = {
      dependencies = ["services/wikibase-query-service" "pvc/blazegraph"];
      pod.containers.wikibase-query-service = {
        image = "xtruder/wikibase-query-service";
        ports = [{ port = 8000; }];
        mounts = [{
          name = "storage";
          mountPath = "/root/wikidata-query-rdf/dist/target/service/data";
        }];
      };
      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "blazegraph";
      };
    };

    kubernetes.services.wikibase-query-service.ports = [{port = 8000;}];

    kubernetes.pvc.blazegraph = {
      name = "blazegraph";
      size = "1G";
    };
  };
}
