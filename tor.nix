{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tor;
in {
  options.services.tor = {
    enable = mkEnableOption "tor";

    proxyDeployments = mkOption {
      description = "List of deployments to proxy through tor";
      type = types.listOf types.str;
      default = [];
    };

    whitelistAddresses = mkOption {
      type = types.listOf types.str;
      description = "List of adddresses to whitelist";
      default = [
        #LAN destinations that shouldn't be routed through Tor
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"

        #Other IANA reserved blocks (These are not processed by tor and dropped by default)
        "0.0.0.0/8"
        "100.64.0.0/10"
        "169.254.0.0/16"
        "192.0.0.0/24"
        "192.0.2.0/24"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/3"
      ];
    };

    hiddenService = {
      enable = mkEnableOption "tor hidden service";

      expose = mkOption {
        default = {};
        type = types.attrsOf (types.submodule  ({config, name, ...}: {
          options = {
            name = mkOption {
              description = "Name of the service (by default attribute name)";
              type = types.str;
              default = name;
            };

            bind = mkOption {
              description = "Port to bind on tor network";
              type = types.int;
            };

            port = mkOption {
              description = "Port that is exposed on service";
              type = types.int;
              default = config.bind;
            };
          };
        }));
        description = "Port mappings";
        example = {
          hello.bind = 80;
        };
      };
    };
  };

  config = mkMerge [(mkIf cfg.hiddenService.enable {
    kubernetes.deployments.tor-hidden-service = {
      dependencies = ["pvc/tor-hidden-service"];

      pod.containers.tor = {
        image = "goldy/tor-hidden-service";
        env = mapAttrs' (name: value:
          nameValuePair "${toUpper value.name}_PORTS" "${toString value.bind}:${toString value.port}"
        ) cfg.hiddenService.expose;
        mounts = [{
          name = "config";
          mountPath = "/var/lib/tor/hidden_service/";
        }];
        ports = [{ port = 15672; }];
      };

      pod.volumes.config = {
        type = "persistentVolumeClaim";
        options.claimName = "tor-hidden-service";
      };
    };

    kubernetes.pvc.tor-hidden-service.size = "1G";
  }) (mkIf cfg.enable {
    kubernetes.deployments = listToAttrs (map (name: nameValuePair name {
      dependencies = ["secrets/tor"];

      pod.containers.tor = {
        image = "beli/tor";
        mounts = [{
          name = "torrc";
          mountPath = "/etc/tor";
        }];
      };

      pod.annotations = {
        "pod.beta.kubernetes.io/init-containers" = builtins.toJSON [{
          name = "route-tor";
          image = "alpine";
          imagePullPolicy = "IfNotPresent";
          command = ["/bin/sh" "-c" ''
            apk add -U iproute2

            iptables -t nat -A OUTPUT -d 10.192.0.0/10 -p tcp --syn -j REDIRECT --to-ports 9040
            iptables -t nat -A OUTPUT -o lo -j RETURN

            #whitelist addresses
            ${concatMapStrings (address: ''
              iptables -t nat -A OUTPUT -d ${address} -j RETURN
            '') cfg.whitelistAddresses}

            #redirect all other pre-routing and output to Tor
            iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040
          ''];
          securityContext.privileged = true;
        }];
      };

      pod.volumes.torrc = {
        type = "secret";
        options.secretName = "tor";
      };
    }) cfg.proxyDeployments);

    kubernetes.secrets.tor = {
      secrets."torrc" = pkgs.writeText "torrc" ''
        VirtualAddrNetworkIPv4 10.192.0.0/10
        AutomapHostsOnResolve 1
        TransPort 9040
        DNSPort 9053
      '';
    };
  })];
}
