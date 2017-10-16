{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vault;
in {
  options.services.vault = {
    enable = mkEnableOption "Vault service";

    version = mkOption {
      description = "Version of image";
      type = types.str;
      default = "latest";
    };

    configuration = mkOption {
      description = "Vault configuration file content";
      type = types.attrs;
    };

    replicas = mkOption {
      description = "Number of vault replicas to deploy";
      default = 2;
      type = types.int;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.vault = {
      dependencies = ["services/vault"];

      replicas = cfg.replicas;

      pod.containers.vault = {
        image = "vault";
        args = ["vault" "server" "-config=/vault/config"];
        security.capabilities.add = ["IPC_LOCK"];
        env = {
          VAULT_LOCAL_CONFIG = builtins.toJSON cfg.configuration;
          SKIP_SETCAP = "true";
          VAULT_CLUSTER_INTERFACE = "eth0";
          VAULT_REDIRECT_INTERFACE = "eth0";
        };
        requests.memory = "50Mi";
        requests.cpu = "50m";
        limits.memory = "128Mi";
        limits.cpu = "500m";
      };

      pod.containers.vault-ui = {
        image = "djenriquez/vault-ui";
        env = {
          VAULT_URL_DEFAULT = "http://localhost:8200";
          VAULT_AUTH_DEFAULT = "USERNAMEPASSWORD";
        };
        requests.memory = "50Mi";
        requests.cpu = "50m";
        limits.memory = "128Mi";
        limits.cpu = "500m";
      };
    };

    kubernetes.services.vault.ports = [{
      name = "vault";
      port = 8200;
      targetPort = 8200;
    }
    {
      name = "vault-ui";
      port = 80;
      targetPort = 8000;
    }];
  };
}
