{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.kibana;

  scheme = if cfg.elasticsearch.ssl then "https" else "http";

  url =
    if (cfg.elasticsearch.username!=null && cfg.elasticsearch.password!=null)
    then
      "${scheme}://${cfg.elasticsearch.username}:${cfg.elasticsearch.password}@${cfg.elasticsearch.host}:${toString cfg.elasticsearch.port}"
    else
      "${scheme}://${cfg.elasticsearch.host}:${toString cfg.elasticsearch.port}";
in {
  options.services.kibana = {
    enable = mkEnableOption "kibana service";

    version = mkOption {
      description = "Version of kibana to use";
      default = "5.2.2";
      type = types.str;
    };

    elasticsearch.host = mkOption {
      description = "Elasticsearch url";
      default = "elasticsearch";
      type = types.str;
    };

    elasticsearch.port = mkOption {
      description = "Elasticsearch port";
      default = 443;
      type = types.int;
    };

    elasticsearch.ssl = mkOption {
      description = "Enable Elasticsearch https";
      default = true;
      type = types.bool;
    };

    elasticsearch.username = mkOption {
      description = "Elasticsearch username";
      type = types.nullOr types.str;
      default = null;
    };

    elasticsearch.password = mkOption {
      description = "Elasticsearch password";
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.kibana = {
      dependencies = ["services/kibana"];
      pod.containers.kibana = {
        image = "kibana:${cfg.version}";
        command = ["/usr/share/kibana/bin/kibana" "-e" "${url}"];
        ports = [{ port = 5601; }];

        requests.memory = "256Mi";
        limits.memory = "256Mi";
      };
    };

    kubernetes.services.kibana.ports = [{ port = 80; targetPort = 5601; }];
  };
}
