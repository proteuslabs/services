{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nginx-ingress;
in {
  options.services.nginx-ingress = {
    enable = mkEnableOption "nginx-ingress";

    externalIPs = mkOption {
      description = "List of external IPs";
      type = types.listOf types.str;
      default = null;
    };

    namespace = mkOption {
      description = "Namespace for nginx-ingress";
      type = types.str;
      default = config.kubernetes.defaultNamespace;
    };

    defaultBackendService = mkOption {
      description = "Default service, used for custom 404 page (must expose port 80 and have livenessProbe)";
      type = types.nullOr types.str;
      default = null;
      example = "default/default-http-backend";
    };

    defaultSslCertSecret = mkOption {
      description = "Default ssl secret to use";
      type = types.nullOr types.str;
      default = null;
      example = "default/ingress-ssl";
    };

    serviceType = mkOption {
      description = "Service type (ClusterIP, NodePort, LoadBalancer)";
      type = types.enum ["ClusterIP" "NodePort" "LoadBalancer"];
      default = "ClusterIP";
    };

    securePort = mkOption {
      description = "Secure port";
      type = types.int;
      default = 443;
    };

    insecurePort = mkOption {
      description = "Insecure port";
      type = types.int;
      default = 80;
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    kubernetes.configMaps.nginx-ingress.data = {
      proxy-connect-timeout = "30";
      proxy-read-timeout = "600";
      proxy-send-timeout = "600";
      hsts-include-subdomains = "false";
      body-size = "64m";
      server-name-hash-bucket-size = "256";
    };

    kubernetes.deployments.nginx-ingress = {
      dependencies = [
        "services/nginx-ingress"
        "configmaps/nginx-ingress"
        "serviceaccounts/nginx-ingress"
        "roles/nginx-ingress"
        "clusterroles/nginx-ingress"
      ] ++ (
        optionals (
          cfg.defaultBackendService == null
        ) ["deployments/default-http-backend"]
      );

      pod.serviceAccountName = "nginx-ingress";
      pod.containers.nginx-ingress = {
        # when update, check if ssl works
        image = "gcr.io/google_containers/nginx-ingress-controller:0.9.0-beta.2";
        readinessProbe = {
          httpGet = {
            path = "/healthz";
            port = 10254;
          };
        };
        livenessProbe = {
          httpGet = {
            path = "/healthz";
            port = 10254;
          };
          initialDelaySeconds = 10;
          timeoutSeconds = 1;
        };
        env = {
          POD_IP = { fieldRef.fieldPath = "status.podIP"; };
          POD_NAME = "nginx-ingress";
          POD_NAMESPACE = cfg.namespace;
        };
        ports = [{ port = 80; } { port = 443; }];
        args = [
          "/nginx-ingress-controller"
          "--default-backend-service=${if cfg.defaultBackendService == null then "${cfg.namespace}/default-http-backend" else cfg.defaultBackendService}"
          (optionalString (cfg.defaultSslCertSecret != null)
            "--default-ssl-certificate=$(POD_NAMESPACE)/${cfg.defaultSslCertSecret}")
          "--configmap=$(POD_NAMESPACE)/nginx-ingress"
        ];
      };

      pod.labels.app = "nginx-ingress";
      pod.labels.k8s-app = "nginx-ingress";
      labels.k8s-app = "nginx-ingress";
      labels.name = "nginx-ingress";
    };

    kubernetes.services.nginx-ingress = {
      type = cfg.serviceType;
      ports = [
        {
          targetPort = 80;
          port = cfg.insecurePort;
          name = "http";
        }
        {
          targetPort = 443;
          port = cfg.securePort;
          name = "https";
        }
      ];
      selector.app = "nginx-ingress";
      selector.k8s-app = "nginx-ingress";
    } // (optionalAttrs (cfg.externalIPs != null) {
      externalIPs = cfg.externalIPs;
    });

    kubernetes.serviceAccounts.nginx-ingress = {};

    kubernetes.clusterRoles.nginx-ingress = {
      rules = [{
        apiGroups = [""];
        resources = ["configmaps" "endpoints" "nodes" "pods" "secrets"];
        verbs = ["get" "list" "watch"];
      } {
        apiGroups = [""];
        resources = ["services"];
        verbs = ["get" "list" "watch"];
      } {
        apiGroups = ["extensions"];
        resources = ["ingresses"];
        verbs = ["get" "list" "watch"];
      } {
        apiGroups = [""];
        resources = ["events"];
        verbs = ["create" "patch"];
      } {
        apiGroups = ["extensions"];
        resources = ["ingresses/status"];
        verbs = ["update"];
      }];
    };

    kubernetes.roles.nginx-ingress = {
      rules = [{
        apiGroups = [""];
        resources = ["configmaps" "pods" "secrets"];
        verbs = ["get" "create" "update"];
      } {
        apiGroups = [""];
        resources = ["endpoints"];
        verbs = ["get" "create" "update"];
      }];
    };

    kubernetes.roleBindings.nginx-ingress = {
      roleRef = {
        kind = "Role";
        name = "nginx-ingress";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "nginx-ingress";
        namespace = cfg.namespace;
      }];
    };

    kubernetes.clusterRoleBindings.nginx-ingress = {
      roleRef = {
        kind = "ClusterRole";
        name = "nginx-ingress";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "nginx-ingress";
        namespace = cfg.namespace;
      }];
    };

  } (mkIf (cfg.defaultBackendService == null) {

    kubernetes.deployments.default-http-backend = {
      dependencies = ["services/default-http-backend"];
      pod.containers.default-http-backend = {
        image = "gcr.io/google_containers/defaultbackend:1.0";
        ports = [{ port = 8080; }];
        livenessProbe = {
          httpGet = {
            path = "/healthz";
            port = 8080;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 5;
        };
        limits = {
          cpu = "10m";
          memory = "20Mi";
        };
        requests = {
          cpu = "10m";
          memory = "20Mi";
        };
      };
    };

    kubernetes.services.default-http-backend.ports = [{
      port = 80;
      targetPort = 8080;
    }];

  })]);
}
