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
     kubernetes.controllers.elasticsearch = {
       dependencies = ["services/elasticsearch" "pvc/elasticsearch"];
       pod.containers.elasticsearch = {
         image = "quay.io/pires/docker-elasticsearch-kubernetes:1.7.2";
         env = {
           NAMESPACE = config.kubernetes.namespace.name;
           CLUSTER_NAME = cfg.clusterName;
           NODE_MASTER = "true";
           NODE_DATA = "true";
           HTTP_ENABLE = "true";
         };
         ports = [{ port = 9200; } { port = 9300; }];
         mounts = [{
           name = "storage";
           mountPath = "/data";
         }];
         security.capabilities.add = ["IPC_LOCK"];
       };

       pod.volumes.storage = {
         type = "persistentVolumeClaim";
         options.claimName = "elasticsearch";
       };
     };

     kubernetes.services.elasticsearch.ports = [{ port = 9200; }];

     kubernetes.pvc.elasticsearch.size = "1G";
   };
 }
