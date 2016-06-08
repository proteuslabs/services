{ config, pkgs, lib, ... }:

 with lib;

 let
   cfg = config.services.sinopia;

   cfgFile = {
     storage = "../storage/cache";
     web.title = "Private NPM registry";
     uplink.npmjs.url = "https://registry.npmjs.org/";
     auth.htpasswd.file = "../storage/htpasswd";
     packages = {
       "@*/*" = {
         allow_access = "$all";
         allow_publish = "$authenticated";
       };
       "*" = {
         allow_access = "$all";
         allow_publish = "$authenticated";
         proxy = "npmjs";
       };
     };
     listen = "0.0.0.0:80";
     logs = [{
       type = "stdout";
       format = "pretty";
       level = "http";
     }];
   };
 in {
   options.services.sinopia = {
     enable = mkEnableOption "sinopia service";
   };

   config = mkIf cfg.enable {
     kubernetes.controllers.sinopia = {
       dependencies = ["services/sinopia" "pvc/sinopia" "secrets/sinopia"];
       pod.containers.elasticsearch = {
         image = "rnbwd/sinopia";
         command = ["./bin/sinopia" "-c" "./conf/config.yaml"];
         ports = [{ port = 80; }];
         mounts = [{
           name = "storage";
           mountPath = "/sinopia/storage";
         } {
           name = "config";
           mountPath = "/sinopia/conf";
         }];

         requests.memory = "512Mi";
         requests.cpu = "250m";
         limits.memory = "768Mi";
       };

       pod.volumes.storage = {
         type = "persistentVolumeClaim";
         options.claimName = "sinopia";
       };

       pod.volumes.config = {
         type = "secret";
         options.secretName = "sinopia";
       };
     };

     kubernetes.services.sinopia.ports = [{ port = 80; }];

     kubernetes.pvc.sinopia.size = "1G";

     kubernetes.secrets.sinopia = {
       secrets."config.yaml" = pkgs.runCommand "config.yaml" {
          buildInputs = [pkgs.remarshal];
        } ''
          remarshal -if json -of yaml -i ${
            pkgs.writeText "config.json" (builtins.toJSON cfgFile)
          } > $out
        '';
     };
   };
 }
