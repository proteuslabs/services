{ config, lib, ... }:

with lib;

let
  cfg = config.services.kube-state-metrics;
in {
  options.services.kube-state-metrics = {
    enable = mkEnableOption "kubernetes state metrics";

    version = mkOption {
      description = "Version of image to use";
      default = "v0.5.0";
      type = types.str;
    };

    namespace = mkOption {
      description = "Namespace to deploy to";
      default = config.kubernetes.defaultNamespace;
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.kube-state-metrics = {
      inherit (cfg) namespace;

      replicas = mkDefault 2;
      dependencies = [
        "services/kube-state-metrics"
        "serviceaccounts/kube-state-metrics"
        "clusterroles/kube-state-metrics"
        "clusterrolebindings/kube-state-metrics"
      ];
      pod.serviceAccountName = "kube-state-metrics";
      pod.containers.kube-state-metrics = {
        image = "gcr.io/google_containers/kube-state-metrics:${cfg.version}";
        ports = [{ port = 8080; }];
        readinessProbe.httpGet = {
          path = "/healthz";
          port = 8080;
        };
        requests = {
          memory = "30Mi";
          cpu = "100m";
        };
        limits = {
          memory = "50Mi";
          cpu = "200m";
        };
      };
    };

    kubernetes.services.kube-state-metrics = {
      inherit (cfg) namespace;

      annotations."prometheus.io/scrape" = "true";
      ports = [{ port = 8080; }];
    };

    kubernetes.clusterRoleBindings.kube-state-metrics = {
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "kube-state-metrics";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "kube-state-metrics";
        inherit (cfg) namespace;
      }];
    };

    kubernetes.clusterRoles.kube-state-metrics = {
      rules = [{
        apiGroups = [""];
        resources = [
          "nodes"
          "pods"
          "services"
          "resourcequotas"
          "replicationcontrollers"
          "limitranges"
        ];
        verbs = ["list" "watch"];
      } {
        apiGroups = ["extensions"];
        resources = [
          "daemonsets"
          "deployments"
          "replicasets"
        ];
        verbs = ["list" "watch"];
      }];
    };

    kubernetes.serviceAccounts.kube-state-metrics = {
      inherit (cfg) namespace;
    };
  };
}
