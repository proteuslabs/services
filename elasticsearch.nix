{ config, lib, ... }:

 with lib;

 let
   cfg = config.services.elasticsearch;
 in {
   options.services.elasticsearch = {
     enable = mkEnableOption "elasticsearch service";

     clusterName = mkOption {
       description = "Name of the cluster";
       type = types.str;
     };
   };

   config = mkIf cfg.enable {
     kubernetes.deployments.elasticsearch = {
       dependencies = ["services/elasticsearch" "pvc/elasticsearch"];

       pod.containers.elasticsearch = {
         image = "gatehub/elasticsearch";
         ports = [{ port = 9200; }];
         mounts = [{
           name = "storage";
           mountPath = "/usr/share/elasticsearch/data";
         }];

         env = {
            ES_HEAP_SIZE = "2g";
         };

         requests.memory = "4096Mi";
         requests.cpu = "1000m";

         security.capabilities.add = ["IPC_LOCK"];
       };

       pod.volumes.storage = {
         type = "persistentVolumeClaim";
         options.claimName = "elasticsearch";
       };
     };

     kubernetes.services.elasticsearch.ports = [{ port = 9200; }];

     kubernetes.pvc.elasticsearch.size = mkDefault "1G";
   };
 }
