{ config, lib, ... }:

with lib;

let
  cfg = config.services.kibana;
in {
  options.services.kibana = {
    enable = mkEnableOption "kibana service";

    version = mkOption {
      description = "Version of kibana to use";
      default = "4.1.1";
      type = types.str;
    };

    elasticsearchUrl = mkOption {
      description = "Elasticsearch url";
      default = "http://10.231.248.73:9200";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.kibana = {
      dependencies = ["services/kibana"];
      pod.containers.kibana = {
        image = "quay.io/pires/docker-kibana:${cfg.version}";
        env = {
          KIBANA_ES_URL = cfg.elasticsearchUrl;
          KIBANA_TRUST_CERT = "true";
        };
        ports = [{ port = 5601; }];
      };
    };

    kubernetes.services.kibana.ports = [{ port = 80; targetPort = 5601; }];
  };
}
