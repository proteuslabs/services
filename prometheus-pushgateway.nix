{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.prometheus-pushgateway;

in {
  options.services.prometheus-pushgateway = {
    enable = mkEnableOption "prometheus pushgateway server";

    version = mkOption {
      description = "Prometheus pushgateway server version";
      type = types.str;
      default = "v0.4.0";
    };

    replicas = mkOption {
      description = "Number of prometheus gateway replicas";
      type = types.int;
      default = 2;
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.extraScrapeConfigs = [{
      job_name = "prometheus-pushgateway";
      honor_labels = true;
      kubernetes_sd_configs.role = "service";
      relabel_configs = [{
        source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_probe"];
        action = "keep";
        regex = "pushgateway";
      }];
    }];

    kubernetes.deployments.prometheus-pushgateway = {
      dependencies = [
        "services/prometheus-pushgateway"
      ];

      # schedule one pod on one node
      pod.annotations."scheduler.alpha.kubernetes.io/affinity" =
        builtins.toJSON {
          podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
            labelSelector = {
              matchExpressions = [{
                key = "name";
                operator = "In";
                values = ["prometheus-pushgateway"];
              }];
            };
            topologyKey = "kubernetes.io/hostname";
          }];
        };

      replicas = mkDefault cfg.replicas;

      pod.containers.pushgateway = {
        image = "prom/pushgateway:${cfg.version}";
        ports = [{ port = 9091; }];

        requests = {
          memory = "128Mi";
          cpu = "10m";
        };

        limits = {
          memory = "128Mi";
          cpu = "100m";
        };

        livenessProbe = {
          httpGet = {
            path = "/#/status";
            port = 9091;
          };
          initialDelaySeconds = 10;
          timeoutSeconds = 10;
        };
      };
    };

    kubernetes.services.prometheus-pushgateway = {
      annotations."prometheus.io/probe" = "pushgateway";
      ports = [{
        port = 9091;
      }];
    };
  };
}
