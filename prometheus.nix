{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.prometheus;

  prometheusConfig = {
    rule_files = ["/etc/config/*.rules" "/etc/config/*.alerts"];
    scrape_configs = [

			# Scrape config for prometheus itself
			{
				job_name = "prometheus";
				static_configs = [{targets = ["localhost:9090"];}];
			}

      # A scrape configuration for running Prometheus on a Kubernetes cluster.
      # This uses separate scrape configs for cluster components (i.e. API server, node)
      # and services to allow each to use different authentication configs.
      #
      # Kubernetes labels will be added as Prometheus labels on metrics via the
      # `labelmap` relabeling action.
			
			# Scrape config for API servers.
			#
			# Kubernetes exposes API servers as endpoints to the default/kubernetes
			# service so this uses `endpoints` role and uses relabelling to only keep
			# the endpoints associated with the default/kubernetes service using the
			# default named port `https`. This works for single API server deployments as
			# well as HA API server deployments. 
			{
				job_name = "kubernetes-apiservers";
				kubernetes_sd_configs = [{role = "endpoints";}];
				scheme = "https";
				tls_config = {
					ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
					insecure_skip_verify = true;
				};
				bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token";
				relabel_configs = [{
					source_labels = [
						"__meta_kubernetes_namespace"
						"__meta_kubernetes_service_name"
						"__meta_kubernetes_endpoint_port_name"
					];
					action = "keep";
					regex = "default;kubernetes;https";
				}];
			}  

			{
				job_name = "kubernetes-nodes";
				scheme = "https";
				tls_config = {
					ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
					insecure_skip_verify = true;
				};
				bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token";
				kubernetes_sd_configs = [{ role = "node"; }];
				relabel_configs = [{
					action = "labelmap";
					regex = "__meta_kubernetes_node_label_(.+)";
				}];
			}

			# Scrape config for service endpoints.
			#
			# The relabeling allows the actual service scrape endpoint to be configured
			# via the following annotations:
			#
			# * `prometheus.io/scrape`: Only scrape services that have a value of `true`
			# * `prometheus.io/scheme`: If the metrics endpoint is secured then you will need
			# to set this to `https` & most likely set the `tls_config` of the scrape config.
			# * `prometheus.io/path`: If the metrics path is not `/metrics` override this.
			# * `prometheus.io/port`: If the metrics are exposed on a different port to the
			# service then set this appropriately.
			{
				job_name = "kubernetes-service-endpoints";
				kubernetes_sd_configs = [{role = "endpoints";}];
				relabel_configs = [{
					source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"];
					action = "keep";
					regex = true;
				} {
					source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scheme"];
					action = "replace";
					target_label = "__scheme__";
					regex = "(https?)";
				} {
					source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"];
					action = "replace";
					target_label = "__metrics_path__";
					regex = "(.+)";
				} {
					source_labels = ["__address__" "__meta_kubernetes_service_annotation_prometheus_io_port"];
					action = "replace";
					target_label = "__address__";
					regex = "([^:]+)(?::\d+)?;(\d+)";
					replacement = "$1:$2";
				} {
					action = "labelmap";
					regex = "__meta_kubernetes_service_label_(.+)";
				} {
					source_labels = ["__meta_kubernetes_namespace"];
					action = "replace";
					target_label = "kubernetes_namespace";
				} {
					source_labels = ["__meta_kubernetes_service_name"];
					action = "replace";
					target_label = "kubernetes_name";
				}];
			}
			
			# Example scrape config for probing services via the Blackbox Exporter.
			#
			# The relabeling allows the actual service scrape endpoint to be configured
			# via the following annotations:
			#
			# * `prometheus.io/probe`: Only probe services that have a value of `true`
			{
				job_name = "kubernetes-services";
				metrics_path = "/probe";
        params.module = ["http_2xx"];
				kubernetes_sd_configs = [{role = "service";}];
				relabel_configs = [{
					source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_probe"];
					action = "keep";
					regex = true;
				} {
					source_labels = ["__address__"];
					target_label = "__param_target";
				} {
					target_label = "__address__";
					replacement = "blackbox";
				} {
					source_labels = ["__param_target"];
					target_label = "instance";
				} {
					action = "labelmap";
					regex = "__meta_kubernetes_service_label_(.+)";
				} {
					source_labels = ["__meta_kubernetes_namespace"];
					target_label = "kubernetes_namespace";
				} {
					source_labels = ["__meta_kubernetes_service_name"];
					target_label = "kubernetes_name";
				}];
			}

			# Example scrape config for pods
			#
			# The relabeling allows the actual pod scrape endpoint to be configured via the
			# following annotations:
			#
			# * `prometheus.io/scrape`: Only scrape pods that have a value of `true`
			# * `prometheus.io/path`: If the metrics path is not `/metrics` override this.
			# * `prometheus.io/port`: Scrape the pod on the indicated port instead of the
			# pod's declared ports (default is a port-free target if none are declared).
			{
				job_name = "kubernetes-pods";
				kubernetes_sd_configs = [{role = "pod";}];
				relabel_configs = [{
					source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"];
					action = "keep";
					regex = true;
				} {
					source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"];
					action = "replace";
					target_label = "__metrics_path__";
					regex = "(.+)";
				} {
					source_labels = ["__address__" "__meta_kubernetes_pod_annotation_prometheus_io_port"];
					action = "replace";
					regex = "([^:]+)(?::\d+)?;(\d+)";
					replacement = "$1:$2";
          target_label = "__address__";
				} {
					action = "labelmap";
					regex = "__meta_kubernetes_pod_label_(.+)";
				} {
					source_labels = ["__meta_kubernetes_namespace"];
					action = "replace";
					target_label = "kubernetes_namespace";
				} {
					source_labels = ["__meta_kubernetes_pod_name"];
					action = "replace";
					target_label = "kubernetes_pod_name";
				}];
			}
		];
  };
in {
  options.services.prometheus = {
    enable = mkEnableOption "prometheus server";

    alertmanager = {
      enable = mkOption {
        description = "Whether to enable prometheus alertmanager";
        default = true;
        type = types.bool;
      };

      url = mkOption {
        description = "Alertmanager url";
        default = "http://alertmanager:9093";
        type = types.str;
      };
    };

    rules = mkOption {
      description = "Attribute set of prometheus recording rules to deploy";
      default = {};
    };

    alerts = mkOption {
      description = "Attribute set of alert rules to deploy";
      default = {};
    };

    storage = {
      size = mkOption {
        description = "Prometheus storage size";
        default = "20Gi";
        type = types.str;
      };
    };

    version = mkOption {
      description = "Prometheus server version";
      type = types.str;
      default = "v1.5.2";
    };

    extraArgs = mkOption {
      description = "Prometheus server additional options";
      default = [];
      type = types.listOf types.str;
    };

    extraConfig = mkOption {
      description = "Prometheus extra config";
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.statefulSets.prometheus = {
      dependencies = [
        "services/prometheus"
        "configmaps/prometheus"
        "clusterroles/prometheus"
        "clusterrolebindings/prometheus"
        "serviceaccounts/prometheus"
      ];

      replicas = mkDefault 2;

      pod.serviceAccountName = "prometheus";

      # reloads prometheus configuration
      pod.containers.server-reload = {
        image = "jimmidyson/configmap-reload:v0.1";
        args = [
          "--volume-dir=/etc/config"
          "--webhook-url=http://localhost:9090/-/reload"
        ];
        mounts = [{
          name = "config";
          mountPath = "/etc/config";
        }];
      };

      # prometheus server
      pod.containers.server = {
        image = "prom/prometheus:${cfg.version}";
        args = [
          "--config.file=/etc/config/prometheus.json"
          "--storage.local.path=/data"
          "--web.console.libraries=/etc/prometheus/console_libraries"
          "--web.console.templates=/etc/prometheus/consoles"
        ] ++ (optionals (cfg.alertmanager.enable) [
          "--alertmanager.url=${cfg.alertmanager.url}"
        ]) ++ cfg.extraArgs;
        ports = [{ port = 9090; }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        } {
          name = "config";
          mountPath = "/etc/config";
        }];
        readinessProbe = {
          httpGet = {
            path = "/status";
            port = 9090;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 30;
        };
      };

      pod.volumes.config = {
        type = "configMap";
        options.name = "prometheus";
      };

      volumeClaimTemplates.storage = {
        size = cfg.storage.size;
      };
    };

    kubernetes.configMaps.prometheus.data = {
      "prometheus.json" = builtins.toJSON prometheusConfig;
    } // (mapAttrs (name: value: 
      if isString value then value
      else builtins.readFile value
    ) cfg.alerts) // (mapAttrs (name: value: 
      if isString value then value
      else builtins.readFile value
    ) cfg.rules);

    kubernetes.services.prometheus = {
      ports = [{
        port = 9090;
      }];
    };

    kubernetes.clusterRoleBindings.prometheus = {
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "prometheus";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "prometheus";
        namespace = config.kubernetes.clusterRoleBindings.prometheus.namespace;
      }];
    };

    kubernetes.clusterRoles.prometheus = {
      rules = [{
        apiGroups = [""];
        resources = [
          "nodes"
          "nodes/metrics"
          "services"
          "endpoints"
          "pods"
        ];
        verbs = ["get" "list" "watch"];
      } {
        apiGroups = [""];
        resources = [
          "configmaps"
        ];
        verbs = ["get"];
      } {
        nonResourceURLs = ["/metrics"];
        verbs = ["get"];
      }];
    };

    kubernetes.serviceAccounts.prometheus = {};

    services.kube-state-metrics.enable = mkDefault true;
    services.prometheus-node-exporter.enable = mkDefault true;
    #services.prometheus-alertmanager.enable = mkDefault cfg.alertmanager.enable;

    services.grafana.enable = mkDefault true;
    services.grafana.dashboards = {
      "all-nodes-dashboard.json" = ./prometheus/all-nodes-dashboard.json;
      "deployment-dashboard.json" = ./prometheus/deployment-dashboard.json;
      "kubernetes-pods-dashboard.json" = ./prometheus/kubernetes-pods-dashboard.json;
      "node-dashboard.json" = ./prometheus/node-dashboard.json;
      "resource-requests-dashboard.json" = ./prometheus/resource-requests-dashboard.json;
      "prometheus-datasource.json" = {
        access = "proxy";
        basicAuth = false;
        name = "prometheus";
        type = "prometheus";
        url = "http://10.0.0.203:9090";
      };
    };

    services.prometheus.rules = mkDefault {
      "kubernetes.alerts" = ./prometheus/kubernetes.rules;
    };

    services.prometheus.alerts = mkDefault {
      "alertmanager.rules" = ./prometheus/alertmanager.rules;
      "general.rules" = ./prometheus/alertmanager.rules;
      "kube-apiserver.rules" = ./prometheus/kube-apiserver.rules;
      "kubelet.rules" = ./prometheus/kubelet.rules;
      "low-disk-space.rules" = ./prometheus/low-disk-space.rules;
    };
  };
}
