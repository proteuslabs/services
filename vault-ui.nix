{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vault-ui;
in {
  options.services.vault-ui = {
    enable = mkEnableOption "Vault service";

    version = mkOption {
      description = "Version of image";
      type = types.str;
      default = "latest";
    };

    replicas = mkOption {
      description = "Number of vault replicas to deploy";
      default = 2;
      type = types.int;
    };

    vault.default = {
      url = mkOption {
        description = "Default vault url";
        type = types.str;
        default = "http://vault:8200";
      };

      auth = mkOption {
        description = "Default vault auth method";
        type = types.enum ["USERNAMEPASSWORD"];
        default = "USERNAMEPASSWORD";
      };
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.vault-ui = {
      dependencies = ["services/vault"];

      replicas = cfg.replicas;

      pod.containers.vault-ui = {
        image = "djenriquez/vault-ui:${cfg.version}";
        env = {
          VAULT_URL_DEFAULT = cfg.vault.default.url;
          VAULT_AUTH_DEFAULT = cfg.vault.default.auth;
        };
        requests.memory = "50Mi";
        requests.cpu = "100m";
        limits.memory = "128Mi";
        limits.cpu = "500m";
      };
    };

    kubernetes.services.vault-ui.ports = [{
      name = "vault-ui";
      port = 80;
      targetPort = 8000;
    }];
  };
}
