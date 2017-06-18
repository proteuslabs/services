{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.parity;
in {
  options.services.parity = {
    enable = mkEnableOption "parity service";

    version = mkOption {
      description = "Parity version to deploy";
      default = "v1.6.7";
      type = types.str;
    };

    storageSize = mkOption {
      description = "Parity storage size";
      default = "100G";
      type = types.str;
    };

    jsonrpc.apis = mkOption {
      description = "List of exposed RPC apis";
      type = types.listOf types.str;
      default = ["eth" "net" "web3"];
    };

    jsonrpc.hosts = mkOption {
      description = "Which hosts are allowed to connect to json rpc";
      type = types.listOf types.str;
      default = ["all"];
    };

    chain = mkOption {
      description = "Which eth chain to use";
      type = types.enum ["classic" "homestead" "ropsten"];
      default = "homestead";
    };

    nodePort = mkOption {
      description = "Node port to listen for p2p traffic";
      type = types.int;
      default = 30303;
    };

    extraOptions = mkOption {
      description = "Extra parity options";
      default = [];
      type = types.listOf types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.statefulSets.parity = {
      dependencies = ["services/parity"];

      # schedule one pod on one node
      pod.annotations."scheduler.alpha.kubernetes.io/affinity" =
        builtins.toJSON {
          podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
            labelSelector = {
              matchExpressions = [{
                key = "name";
                operator = "In";
                values = ["parity"];
              }];
            };
            topologyKey = "kubernetes.io/hostname";
          }];
        };

      pod.containers.parity = {
        image = "ethcore/parity:${cfg.version}";
        command = [
          "/parity/parity"
          ''--jsonrpc-apis=${concatStringsSep "," cfg.jsonrpc.apis}''
          "--jsonrpc-interface=all"
          "--geth"
          "--chain=${cfg.chain}"
          "--jsonrpc-hosts=${concatStringsSep "," cfg.jsonrpc.hosts}"
          "--port=${toString cfg.nodePort}"
          "--warp"
          "--allow-ips=public"
          "--max-pending-peers=32"
        ];
        mounts = [{
          name = "storage";
          mountPath = "/root/.local/share/io.parity.ethereum";
        }];
        ports = [{ port = 8545; } { port = cfg.nodePort; }];
        requests.memory = "8000Mi";
        requests.cpu = "1000m";
        limits.memory = "8000Mi";
      };

      volumeClaimTemplates.storage.size = cfg.storageSize;
    };

    kubernetes.services.parity = {
      type = "NodePort";
      ports = [{
        name = "parity";
        port = 8545;
      } {
        name = "parity-node";
        port = cfg.nodePort;
        targetPort = cfg.nodePort;
        nodePort = cfg.nodePort;
      }];
    };
  };
}
