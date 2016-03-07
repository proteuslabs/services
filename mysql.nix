 { config, lib, ... }:

 with lib;

 let
   cfg = config.services.mysql;
 in {
   options.services.mysql = {
     enable = mkEnableOption "mysql service";

     rootPassword = mkOption {
       description = "Root password";
       type = types.str;
     };

     database = mkOption {
       description = "Database to pre create";
       type = types.nullOr types.str;
       default = null;
     };

     user = mkOption {
       description = "Databse user";
       type = types.nullOr types.str;
       default = null;
     };

     password = mkOption {
       description = "Database password";
       type = types.str;
       default = null;
     };
   };

   config = mkIf cfg.enable {
     kubernetes.controllers.mysql = {
       pod.containers.mysql = {
         image = "mysql:5.6";
         env = {
           MYSQL_ROOT_PASSWORD = cfg.rootPassword;
           MYSQL_DATABASE = mkIf (cfg.database != null) cfg.database;
           MYSQL_USER = mkIf (cfg.user != null) cfg.user;
           MYSQL_PASSWORD = mkIf (cfg.password != null) cfg.password;
         };
         mounts = [{
           name = "storage";
           mountPath = "/var/lib/mysql";
         }];
       };

       pod.volumes.storage = {
         type = "persistentVolumeClaim";
         options.claimName = "mysql";
       };
     };

     kubernetes.services.mysql.ports = [{ port = 3306; }];

     kubernetes.pvc.mysql = {
       name = "mysql";
       size = "1G";
     };
   };
 }
