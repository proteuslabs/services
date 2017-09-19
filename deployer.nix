{ config, lib, ... }:

with lib;

let
  cfg = config.services.deployer;

  mkDefaultsOptions = names: deployer: listToAttrs (map (name:
    {
      inherit name;
      value = mkOption {
        type = types.attrs;
        description = "Default parameters for ${name}";
        default = optionalAttrs (name == "resource") {
          lifecycle = {
            prevent_destroy = deployer.preventDestroy;
          };
        };
      };
    }
  ) names);

  mkSectionsOptions = names: listToAttrs (map (name:
    {
      inherit name;
      value = mkOption {
        type = types.attrs;
        description = "Attribute set of ${name} section";
        default = {};
      };
    }
  ) names);

  deployerOptions = { name, config, ... } : {
    options = {
      enable = mkEnableOption "Enable deployer";
      name = mkOption {
        description = "Name of the deployer";
        type = types.str;
        default = name;
      };
      version = mkOption {
        description = "Deployer version";
        type = types.str;
        default = cfg.defaults.version;
      };
      lockEndpoint = mkOption {
        description = "Etcd lock endpoint";
        type = types.str;
        default = cfg.defaults.lockEndpoint;
      };
      exitOnError = mkOption {
        description = "Exit on error (do not atomatically retry)";
        type = types.bool;
        default = cfg.defaults.exitOnError;
      };
      preventDestroy = mkOption {
        description = "Prevent destroy (do not atomatically destroy resources)";
        type = types.bool;
        default = cfg.defaults.preventDestroy;
      };
      defaults = mkDefaultsOptions [ "resource" "provider" "output" "module" ] cfg.deployers.${name};
    } // (mkSectionsOptions [ "resource" "variable" "data" "provider" "output" "locals" "module" "terraform" ]);
  };

  defaultsOnThirdLevel =
    { deployer, sectionName }:
      mapAttrs (t: v:
        mapAttrs (n: value:
          ((optionalAttrs (deployer.defaults ? "${sectionName}") deployer.defaults.${sectionName}) // value)
        ) v
      ) (optionalAttrs (deployer ? "${sectionName}") deployer.${sectionName});

  defaultsOnSecondLevel =
    { deployer, sectionName }:
      mapAttrs (n: value:
        ((optionalAttrs (deployer.defaults ? "${sectionName}") deployer.defaults.${sectionName}) // value)
      ) (optionalAttrs (deployer ? "${sectionName}") deployer.${sectionName});

  content =
    { deployer }:
    filterAttrs (n: v: v != [] && v != {}) {
      resource = defaultsOnThirdLevel { inherit deployer; sectionName = "resource"; };
      variable = deployer.variable;
      data = deployer.data;
      provider = defaultsOnSecondLevel { inherit deployer; sectionName = "provider"; };
      output = defaultsOnSecondLevel { inherit deployer; sectionName = "output"; };
      locals = deployer.locals;
      module = defaultsOnSecondLevel { inherit deployer; sectionName = "module"; };
      terraform = deployer.terraform;
    };

  configMaps = mapAttrs' (deployerName: deployer: nameValuePair "deployer-${deployer.name}" { "data" = {
    "main.tf.json" = builtins.toJSON (content { inherit deployer; });
  }; }) (filterAttrs (n: v: v.enable) cfg.deployers);

  deployments = mapAttrs' (deployerName: deployer: nameValuePair "deployer-${deployer.name}" {
    dependencies = ["configmaps/deployer-${deployer.name}"];

    pod.containers.deployer = {
      image = "matejc/deployer:${deployer.version}";

      env = {
        LOCK_ENDPOINT = deployer.lockEndpoint;
      } // optionalAttrs deployer.exitOnError {
        EXIT_ON_ERROR = "1";
      };

      requests.memory = "256Mi";
      requests.cpu = "500m";

      mounts = [{
        name = "resources";
        mountPath = "/usr/local/deployer/inputs";
      }];
    };

    pod.volumes.resources = {
      type = "configMap";
      options.name = "deployer-${deployer.name}";
    };
  }) (filterAttrs (n: v: v.enable) cfg.deployers);
in {
  options.services.deployer = {
    defaults = {
      version = mkOption {
        description = "Deployer version";
        type = types.str;
        default = "latest";
      };
      lockEndpoint = mkOption {
        description = "Etcd lock endpoint";
        type = types.str;
        example = "http://etcd:2379/v2/keys/deployer_global_lock";
      };
      exitOnError = mkOption {
        description = "Exit on error (do not atomatically retry)";
        type = types.bool;
        default = false;
      };
      preventDestroy = mkOption {
        description = "Prevent destroy (do not atomatically destroy resources)";
        type = types.bool;
        default = true;
      };
    };
    deployers = mkOption {
      type = types.attrsOf (types.submodule [ deployerOptions ]);
      description = "Attribute set of deployers";
      default = {};
    };
  };

  config = {
    kubernetes.configMaps = configMaps;
    kubernetes.deployments = deployments;
  };
}
