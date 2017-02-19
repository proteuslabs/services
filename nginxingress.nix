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
      proxy-connect-timeout = "15";
      proxy-read-timeout = "600";
      proxy-send-imeout = "600";
      hsts-include-subdomains = "false";
      body-size = "64m";
      server-name-hash-bucket-size = "256";
    };

    kubernetes.deployments.nginx-ingress = {
      dependencies = [
        "services/nginx-ingress"
        "configmaps/nginx-ingress"
      ] ++ (
        optionals (
          cfg.defaultBackendService == null
        ) ["deployments/default-http-backend"]
      );

      pod.containers.nginx-ingress = {
        image = "gcr.io/google_containers/nginx-ingress-controller:0.8.3";
        readinessProbe = {
          httpGet = {
            path = "/healthz";
            port = 10254;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 5;
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
          "--nginx-configmap=${cfg.namespace}/nginx-ingress"
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
