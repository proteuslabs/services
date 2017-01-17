{ config, lib, ... }:

with lib;

let
  cfg = config.services.aws-es-kibana;
in {
  options.services.aws-es-kibana = {
    enable = mkEnableOption "aws elasticsearch/kibana proxy";

    endpoint = mkOption {
      description = "AWS cluster endpoint";
      type = types.str;
    };

    accessKeyID = mkOption {
      description = "AWS access key id";
      type = types.str;
    };

    secretAccessKey = mkOption {
      description = "AWS secret access key";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.aws-es-kibana = {
      dependencies = ["services/aws-es-kibana"];
      pod.containers.kibana = {
        image = "rlister/aws-es-kibana";
        args = [cfg.endpoint];
        env = {
          AWS_ACCESS_KEY_ID = cfg.accessKeyID;
          AWS_SECRET_ACCESS_KEY = cfg.secretAccessKey;
        };
        ports = [{ port = 9200; }];

        requests.memory = "64Mi";
        limits.memory = "128Mi";
      };
    };

    kubernetes.services.aws-es-kibana.ports = [{ port = 80; targetPort = 9200; }];
  };
}
