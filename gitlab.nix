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
      default = "9.2.7";
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

    secrets = {
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

      secretKeyBase = mkOption {
        description = ''
           Is used for password reset links, and other 'standard' auth features.
           If you lose or rotate this secret, password reset tokens in emails will reset.
        '';
        type = types.str;
        example = "4xgksdQ98SXXclnn3Z9lz7RBbb3cSdcFhrDnznKfhwVbCbdXZRPPRzwnl9x5r4lh";
      };

      otpKeyBase = mkOption {
        description = ''
          Is used for password reset links, and other 'standard' auth features.
          If you lose or rotate this secret, password reset tokens in emails will reset.
        '';
        type = types.str;
        example = "4xgksdQ98SXXclnn3Z9lz7RBbb3cSdcFhrDnznKfhwVbCbdXZRPPRzwnl9x5r4lh";
      };
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
    kubernetes.deployments.gitlab = {
      dependencies = ["services/gitlab" "pvc/gitlab-db" "pvc/gitlab-redis" "pvc/gitlab-data"];

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
          GITLAB_SECRETS_DB_KEY_BASE = cfg.secrets.dbKeyBase;
          GITLAB_SECRETS_SECRET_KEY_BASE = cfg.secrets.secretKeyBase;
          GITLAB_SECRETS_OTP_KEY_BASE = cfg.secrets.otpKeyBase;
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
          SMTP_STARTTLS = if cfg.smtp.tls then "true" else "false";
          SMTP_AUTHENTICATION = "login";
        };

        requests.memory = "1536Mi";
        requests.cpu = "500m";
        limits.memory = "1700Mi";

        mounts = [{
          name = "data";
          mountPath = "/home/git/data";
        }];
      };

      pod.containers.postgres = {
        image = "sameersbn/postgresql:9.5-4";

        requests.memory = "128Mi";
        requests.cpu = "200m";
        limits.memory = "256Mi";

        env = {
          DB_USER = "gitlab";
          DB_PASS = "gitlab";
          DB_NAME = "gitlab";
          DB_EXTENSION = "pg_trgm";
        };
        mounts = [{
          name = "db";
          mountPath = "/var/lib/postgresql";
        }];
      };

      pod.containers.redis = {
        image = "sameersbn/redis:latest";

        requests.memory = "64Mi";
        requests.cpu = "200m";
        limits.memory = "64Mi";

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

    kubernetes.services.gitlab.ports = [{
      port = 80;
      name = "http";
    } {
      port = 22;
      name = "ssh";
    }];

    kubernetes.pvc.gitlab-db.size = "3G";
    kubernetes.pvc.gitlab-redis.size = "1G";
    kubernetes.pvc.gitlab-data.size = "20G";
  };
}
