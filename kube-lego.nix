{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kube-lego;
in {
  options.services.kube-lego = {
    enable = mkEnableOption "kube-lego";

    namespace = mkOption {
      description = "Namespace for kube-lego";
      type = types.str;
      default = config.kubernetes.defaultNamespace;
    };

    url = mkOption {
      description = "URL for the ACME server (warning: staging url is default)";
      type = types.str;
      default = "https://acme-staging.api.letsencrypt.org/directory";
      example = "https://acme-v01.api.letsencrypt.org/directory";
    };

    email = mkOption {
      description = "E-Mail address for the ACME account, used to recover from lost secrets";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.kube-lego = {
      pod.containers.kube-lego = {
        image = "jetstack/kube-lego:0.1.3";
        env = {
          LEGO_EMAIL = cfg.email;
          LEGO_URL = cfg.url;
          LEGO_NAMESPACE = cfg.namespace;
          LEGO_POD_IP = {fieldRef = {fieldPath = "status.podIP";};};
          # LEGO_LOG_LEVEL = "debug";
        };
        ports = [{ port = 8080; }];
        livenessProbe = {
          httpGet = {
            path = "/healthz";
            port = 8080;
          };
          initialDelaySeconds = 5;
          timeoutSeconds = 1;
        };
      };

      pod.labels.app = "kube-lego";
    };
  };
}
