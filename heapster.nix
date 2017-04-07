{ config, lib, ... }:

with lib;

let
  cfg = config.services.heapster;
in {
  options.services.heapster = {
    enable = mkEnableOption "heapster service";

    sink = mkOption {
      description = "Sink url";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.heapster-monitoring = {
      pod.containers.heapster = {
        image = "gcr.io/google_containers/heapster-amd64:v1.3.0-beta.1";
        command = [
          "/heapster"
          "--source=kubernetes.summary_api:"
          "--sink=${cfg.sink}"
        ];
        requests.memory = "50Mi";
        requests.cpu = "100m";
        limits.memory = "50Mi";
        limits.cpu = "100m";
      };
      pod.containers.eventer = {
        image = "gcr.io/google_containers/heapster-amd64:v1.3.0-beta.1";
        command = [
          "/eventer"
          "--source=kubernetes:"
          "--sink=${cfg.sink}"
        ];
        requests.memory = "50Mi";
        requests.cpu = "100m";
        limits.memory = "50Mi";
        limits.cpu = "100m";
      };
    };
  };
}
