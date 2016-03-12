{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nginx-ingress;
in {
  options.services.nginx-ingress = {
    enable = mkEnableOption "nginx ingress";

    version = mkOption {
      description = "Nginx ingress version to use";
      type = types.str;
      default = "0.3";
    };

    certSecret = mkOption {
      description = "Name of the secret with certs";
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.nginx-ingress = {
      dependencies = ["services/nginx-ingress"];

      labels.k8s-app = "nginx-ingress-lb";

      pod.labels = {
        name = "nginx-ingress-lb";
        k8s-app = "nginx-ingress-lb";
      };

      selector = {
        k8s-app = "nginx-ingress-lb";
      };

      pod.containers.nginx-ingress-lb = {
        image = "gcr.io/google_containers/nginx-third-party:${cfg.version}";
        env = {
          POD_IP = { fieldRef.fieldPath = "status.podIP"; };
          POD_NAME = { fieldRef.fieldPath = "metadata.name"; };
          POD_NAMESPACE = { fieldRef.fieldPath = "metadata.namespace"; };
        };
        args = [
          "/nginx-third-party-lb"
          "--default-backend-service=${config.kubernetes.namespace.name}/default-http-backend"
        ];

        ports = [{ port = 80; } { port = 443; } { port = 8080; }];

        mounts = mkIf (cfg.certSecret != null) [{
          mountPath = "/etc/nginx-ssl/default";
          name = "cert";
        }];
      };

      pod.volumes = mkIf (cfg.certSecret != null) {
        cert = {
          type = "secret";
          options.secretName = cfg.certSecret;
        };
      };
    };

    kubernetes.controllers.default-http-backend = {
      dependencies = ["services/default-http-backend"];
      pod.containers.default-http-backend = {
        image = "gcr.io/google_containers/defaultbackend:1.0";
        ports = [{ port = 8080; }];
      };
    };

    kubernetes.services.default-http-backend.ports = [{
      port = 80;
      targetPort = 8080;
    }];

    kubernetes.services.nginx-ingress = {
      type = "LoadBalancer";

      selector.name = "nginx-ingress-lb";

      ports = [{
        port = 80;
        name = "http";
      } {
        port = 443;
        name = "https";
      }];
    };
  };
}
