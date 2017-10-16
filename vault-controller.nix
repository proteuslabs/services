{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vault-controller;
in {
  options.services.vault-controller = {
    enable = mkEnableOption "Vault controller service";

    version = mkOption {
      description = "Version of image";
      type = types.str;
      default = "v0.3.0";
    };

    syncPeriod = mkOption {
      type = types.str;
      default = "1m";
      description = "Secret sync period";
    };

    namespace = mkOption {
      type = types.str;
      description = "Namespace to watch for custom resources";
      default = config.kubernetes.defaultNamespace;
    };

    vault = {
      addr = mkOption {
        description = "Vault address";
        default = "http://vault:8200";
        type = types.str;
      };

      token = mkOption {
        description = "Vault token";
        type = types.str;
      };
    };
  };

  options.kubernetes.secretClaims = mkOption {
    description = "Attribute set of secret claims";
    default = {};
    type = types.attrsOf (types.submodule ({config, name, ...}: {
      options = {
        name = mkOption {
          description = "Name of secret claim";
          type = types.str;
          default = name;
        };

        type = mkOption {
          description = "Type of the secret";
          type = types.enum ["Opaque" "kubernetes.io/tls"];
          default = "Opaque";
        };

        path = mkOption {
          description = "Vault secret path";
          type = types.str;
        };
      };
    }));
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.vault-controller = {
      dependencies = [
        "customresourcedefinitions/vault-controller"
        "roles/vault-controller"
        "rolebindings/vault-controller"
      ];
      pod.serviceAccountName = "vault-controller";
      pod.containers.vault-controller = {
        image = "xtruder/kube-vault-controller:${cfg.version}";
        args = [
          "/kube-vault-controller"
          "--sync-period=${cfg.syncPeriod}"
          "--namespace=${cfg.namespace}"
        ];
        env = {
          VAULT_ADDR = cfg.vault.addr;
          VAULT_TOKEN = cfg.vault.token;
        };
        requests.memory = "64Mi";
        requests.cpu = "50m";
        limits.memory = "64Mi";
        limits.cpu = "100m";
      };
    };

    kubernetes.serviceAccounts.vault-controller = {};

    kubernetes.roleBindings.vault-controller = {
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "Role";
        name = "vault-controller";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "vault-controller";
      }];
    };

    kubernetes.roles.vault-controller = {
      rules = [{
        apiGroups = ["vaultproject.io"];
        resources = [
          "secretclaims"
        ];
        verbs = ["get" "list" "watch"];
      } {
        apiGroups = [""];
        resources = [
          "secrets"
        ];
        verbs = ["get" "watch" "list" "create" "update" "patch" "delete"];
      }];
    };

    kubernetes.customResourceDefinitions.vault-controller = {
      name = "secretclaims.vaultproject.io";
      group = "vaultproject.io";
      version = "v1";
      names = {
        plural = "secretclaims";
        kind = "SecretClaim";
        shortNames = ["scl"];
      };
    };

    kubernetes.customResources.vault-controller = mapAttrs (name: config: {
      dependencies = ["customresourcedefinitions/vault-controller"];
      kind = "SecretClaim";
      apiVersion = "vaultproject.io/v1";
      extra.spec = {
        inherit (config) type path;
      };
    }) config.kubernetes.secretClaims;
  };
}
