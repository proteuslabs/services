{ config, lib, ... }:

with lib;

let
  cfg = config.services.kibana;
in {
  options.services.kibana = {
    enable = mkEnableOption "kibana service";

    version = mkOption {
      description = "Version of kibana to use";
      default = "4.6";
      type = types.str;
    };

    elasticsearchUrl = mkOption {
      description = "Elasticsearch url";
      default = "http://elasticsearch:9200";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.kibana = {
      dependencies = ["services/kibana"];
      pod.containers.kibana = {
        image = "kibana:${cfg.version}";
        env = {
          ELASTICSEARCH_URL = cfg.elasticsearchUrl;
        };
        ports = [{ port = 5601; }];

        requests.memory = "64Mi";
        limits.memory = "128Mi";
      };
    };

    kubernetes.services.kibana.ports = [{ port = 80; targetPort = 5601; }];
  };
}
