{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.curator;
  toYAML = config: pkgs.runCommand "to-yaml" {
    buildInputs = [pkgs.remarshal];
  } ''
    remarshal -i ${pkgs.writeText "to-json" (builtins.toJSON config)} -if json -of yaml > $out
  '';
in {
  options.services.curator = {
    hosts = mkOption {
      description = "Elasticsearch hosts";
      default = ["elasticsearch"];
      type = types.listOf types.str;
    };

    port = mkOption {
      description = "Elasticsearch port";
      default = 9200;
      type = types.int;
    };

    ssl = mkOption {
      description = "Whether currator should use ssl or not";
      default = false;
      type = types.bool;
    };

    username = mkOption {
      description = "Simple auth username";
      default = null;
      type = types.nullOr types.str;
    };

     password = mkOption {
      description = "Simple auth password";
      default = null;
      type = types.nullOr types.str;
    };

    aws = {
      key = mkOption {
        description = "Aws key";
        type = types.nullOr types.str;
        default = null;
      };

      secretKey = mkOption {
        description = "Aws secret key";
        type = types.nullOr types.str;
        default = null;
      };

      region = mkOption {
        description = "Aws region";
        type = types.nullOr types.str;
        default = null;
      };
    };

    jobs = mkOption {
      description = "Attribute set of jobs to run";
      type = types.attrsOf types.optionSet;
      default = {};
      options = [{
        enable = mkOption {
          description = "Whether to enable job";
          type = types.bool;
          default = true;
        };

        schedule = mkOption {
          description = "Job schedule";
          type = types.str;
          default = "* * * * *";
        };

        actions = mkOption {
          description = "List of actions to run";
          type = types.listOf types.attrs;
        };
      }];
    };
  };

  config = {
    kubernetes.scheduledJobs = listToAttrs (mapAttrsFlatten (name: job:
      nameValuePair "curator-${name}" {
      dependencies = ["secrets/curator-job-${name}"];
      inherit (job) enable schedule;

      concurrencyPolicy = "Forbid";

      job.activeDeadlineSeconds = 30;
      job.pod.containers.curator =  {
        image = "bobrik/curator:4.2.4";
        args = ["--config" "/etc/curator/config.yml" "/etc/curator/actions.yml"];

        requests.memory = "256Mi";
        requests.cpu = "50m";
        limits.memory = "512Mi";
        limits.cpu = "50m";

        mounts = [{
          name = "config";
          mountPath = "/etc/curator";
        }];
      };

      job.pod.restartPolicy = "Never";

      job.pod.volumes.config = {
        type = "secret";
        options.secretName = "curator-job-${name}";
      };
    }) cfg.jobs);

    kubernetes.secrets = mapAttrs' (name: job: nameValuePair "curator-job-${name}" {
      secrets."config.yml" = toYAML {
        client = {
          inherit (cfg) hosts port;
          use_ssl = cfg.ssl;
          aws_key = cfg.aws.key;
          aws_secret_key = cfg.aws.secretKey;
          aws_region = cfg.aws.region;
        } // (optionalAttrs (cfg.username != null && cfg.password != null) {
          http_auth = "${cfg.username}:${cfg.password}";
        });
        logging = {
          loglevel = "INFO";
          logformat = "json";
        };
      };
      secrets."actions.yml" = toYAML {
        actions = listToAttrs (imap (i: action:
          nameValuePair (toString i) action
        ) job.actions);
      };
    }) cfg.jobs;
  };
}
