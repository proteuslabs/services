{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.kibana;

  url =
    if (cfg.elasticsearch.username!=null && cfg.elasticsearch.password!=null)
    then
      "https://${cfg.elasticsearch.username}:${cfg.elasticsearch.password}@${cfg.elasticsearch.host}:${toString cfg.elasticsearch.port}"
    else
      "https://$${cfg.elasticsearch.host}:${toString cfg.elasticsearch.port}";
in {
  options.services.kibana = {
    enable = mkEnableOption "kibana service";

    version = mkOption {
      description = "Version of kibana to use";
      default = "5.1.2";
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
        command = "/usr/share/kibana/bin/kibana -e ${url}";
        ports = [{ port = 5601; }];

        requests.memory = "256Mi";
        limits.memory = "256Mi";
      };
    };

    kubernetes.services.kibana.ports = [{ port = 80; targetPort = 5601; }];
  };
}
