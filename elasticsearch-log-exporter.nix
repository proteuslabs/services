{ config, lib, ... }:

with lib;

let
  cfg = config.services.elasticsearch-log-exporter;

  logstashConfig = ''
    input {
      elasticsearch {
        hosts => "${cfg.elasticsearch.host}"
        ${optionalString (cfg.elasticsearch.user != null) ''user => "${cfg.elasticsearch.user}"''}
        ${optionalString (cfg.elasticsearch.password != null) ''password => "${cfg.elasticsearch.password}"''}
        ssl => ${if cfg.elasticsearch.ssl then "true" else "false"}

        index => "${cfg.index}"
        query => '${builtins.toJSON {
          query.bool.must = [{
            query_string = {
              query = cfg.query;
              analyze_wildcard = true;
            };
          }];
          sort = [{
            "@timestamp" = {
              order = "desc";
              unmapped_type = "boolean";
            };
          }];
        }}'
        type => "logs"
        enable_metric => false
      }
    }

    filter {
      mutate {
        remove_field => [ "path", "@version", "kubernetes", "host" ]
      }
    }

    output {
      s3 {
        access_key_id => "${cfg.s3.accessKeyID}"
        secret_access_key => "${cfg.s3.secretAccessKey}"
        region => "${cfg.s3.region}"
        bucket => "${cfg.s3.bucket}"
        prefix => "${cfg.s3.prefix}"
        rotation_strategy => "size"
        size_file => 104857600
        codec => "json_lines"
      }
    }
  '';

in {
  options.services.elasticsearch-log-exporter = {
    index = mkOption {
      description = "Index names to export";
      type = types.str;
      default = "logstash-*";
    };

    query = mkOption {
      description = "Elasticsearch query";
      type = types.str;
      default = "*";
    };

    elasticsearch = {
      host = mkOption {
        description = "Elaticsearch host to connect to";
        type = types.str;
        default = "elasticsearch";
      };

      ssl = mkOption {
        description = "Whether to use ssl when connecting to elasticsearch";
        type = types.bool;
        default = true;
      };

      user = mkOption {
        description = "Username fori elasticsearch basic auth";
        type = types.nullOr types.str;
        default = null;
      };

      password = mkOption {
        description = "Password for elasticsearch basic auth";
        type = types.nullOr types.str;
        default = null;
      };
    };

    s3 = {
      accessKeyID = mkOption {
        description = "S3 access key id";
        type = types.str;
        default = "";
      };

      secretAccessKey = mkOption {
        description = "S3 secret access key";
        type = types.str;
        default = "";
      };

      region = mkOption {
        description = "S3 region";
        type = types.str;
        default = "eu-central-1";
      };

      bucket = mkOption {
        description = "S3 bucket name";
        type = types.str;
        default = "logs";
      };

      prefix = mkOption {
        description = "Log file prefix";
        type = types.str;
        default = "exports/logs";
      };
    };
  };

  config = {
    kubernetes.jobs.elasticsearch-log-exporter = {
      pod.containers.logstash = {
        image = "logstash";
        command = ["logstash" "-e" logstashConfig];
        requests.memory = "512Mi";
        limits.memory = "512Mi";
      };
    };
  };
}
