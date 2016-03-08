{ config, lib, pkgs, ... }:

 with lib;

 let
   cfg = config.services.gitlab;
 in {
   options.services.gitlab = {
     enable = mkEnableOption "gitlab service";

     version = mkOption {
       description = "Gitlab version to use";
       type = types.str;
       default = "8.5.1";
     };

     host = mkOption {
       description = "Gitlab host";
       type = types.str;
     };

     email = mkOption {
       description = "Gitlab sending email";
       type = types.str;
       default = config.globals.email;
     };

     replyEmail = mkOption {
       description = "Gitlab reply email";
       type = types.str;
       default = config.globals.replyEmail;
     };

     backups = mkOption {
       description = "Backup schedule";
       type = types.str;
       default = "daily";
     };

     backupTime = mkOption {
       description = "Time when create backups";
       type = types.str;
       default = "00:00";
     };

     dbKeyBase = mkOption {
       description = ''
        db_key_base is used to encrypt for Variables. Ensure that you don't lose it.
        If you change or lose this key you will be unable to access variables stored in database.
        Make sure the secret is at least 30 characters and all random,
        no regular words or you'll be exposed to dictionary attacks.
       '';
       type = types.str;
       example = "4xgksdQ98SXXclnn3Z9lz7RBbb3cSdcFhrDnznKfhwVbCbdXZRPPRzwnl9x5r4lh";
     };

     smtp = {
       domain = mkOption {
         description = "Domain name";
         type = types.str;
         default = config.globals.smtp.domain;
       };

       host = mkOption {
         description = "SMTP host to connect to";
         type = types.str;
         default = config.globals.smtp.host;
       };

       port = mkOption {
         description = "SMTP port";
         type = types.int;
         default = config.globals.smtp.port;
       };

       user = mkOption {
         description = "SMTP user";
         type = types.str;
         default = config.globals.smtp.user;
       };

       pass = mkOption {
         description = "SMTP password";
         type = types.str;
         default = config.globals.smtp.pass;
       };

       tls = mkOption {
         description = "Whether to enable smtp TLS";
         type = types.bool;
         default = config.globals.smtp.tls;
       };
     };
   };

   config = mkIf cfg.enable {
     kubernetes.controllers.gitlab = {
       pod.containers.gitlab = {
         image = "sameersbn/gitlab:${cfg.version}";
         env = {
           GITLAB_TIMEZONE = config.globals.timezone;
           GITLAB_HOST = cfg.host;
           GITLAB_PORT = "80";
           GITLAB_EMAIL = cfg.email;
           GITLAB_EMAIL_REPLY_TO = cfg.replyEmail;
           GITLAB_BACKUPS = cfg.backups;
           GITLAB_BACKUP_TIME = cfg.backupTime;
           GITLAB_SECRETS_DB_KEY_BASE = cfg.dbKeyBase;
           DB_HOST = "localhost";
           DB_TYPE = "postgres";
           DB_PORT = toString 5432;
           DB_NAME = "gitlab";
           DB_USER = "gitlab";
           DB_PASS = "gitlab";
           REDIS_HOST = "localhost";
           REDIS_PORT = toString 6379;
           SMTP_DOMAIN = cfg.smtp.domain;
           SMTP_PORT = toString cfg.smtp.port;
           SMTP_USER = cfg.smtp.user;
           SMTP_PASS = cfg.smtp.pass;
           SMTP_STARTTLS = if cfg.smtp.tls then "yes" else "no";
           SMTP_AUTHENTICATION = "login";
         };

         mounts = [{
           name = "data";
           mountPath = "/home/git/data";
         }];
       };

       pod.containers.postgres = {
         image = "sameersbn/postgresql:9.4-3";
         env = {
           DB_USER = "gitlab";
           DB_PASS = "gitlab";
           DB_NAME = "gitlab";
         };
         mounts = [{
           name = "db";
           mountPath = "/var/lib/postgresql";
         }];
       };

       pod.containers.redis = {
         image = "sameersbn/redis:latest";
         mounts = [{
           name = "redis";
           mountPath = "/var/lib/redis";
         }];
       };

       pod.volumes.db = {
         type = "persistentVolumeClaim";
         options.claimName = "gitlab-db";
       };

       pod.volumes.redis = {
         type = "persistentVolumeClaim";
         options.claimName = "gitlab-redis";
       };

       pod.volumes.data = {
         type = "persistentVolumeClaim";
         options.claimName = "gitlab-data";
       };
     };

     kubernetes.services.mysql.ports = [{ port = 3306; }];

     kubernetes.pvc.gitlab-db.size = "3G";
     kubernetes.pvc.gitlab-redis.size = "1G";
     kubernetes.pvc.gitlab-data.size = "20G";
   };
 }
