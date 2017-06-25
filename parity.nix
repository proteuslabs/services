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

      pod.annotations = {
        "scheduler.alpha.kubernetes.io/affinity" =
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

        "pod.beta.kubernetes.io/init-containers" = builtins.toJSON [{
          name = "drop-private-discovery";
          image = "alpine";
          imagePullPolicy = "IfNotPresent";
          command = ["/bin/sh" "-c" ''
            apk add -U iproute2

            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 0.0.0.0/8 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 10.0.0.0/8 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 100.64.0.0/10 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 169.254.0.0/16 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 172.16.0.0/12 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 192.0.0.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 192.0.2.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 192.88.99.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 192.168.0.0/16 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 198.18.0.0/15 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 198.51.100.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 203.0.113.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 224.0.0.0/4 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p tcp -s 0/0 -d 240.0.0.0/4 -j DROP

            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 0.0.0.0/8 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 10.0.0.0/8 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 100.64.0.0/10 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 169.254.0.0/16 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 172.16.0.0/12 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 192.0.0.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 192.0.2.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 192.88.99.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 192.168.0.0/16 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 198.18.0.0/15 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 198.51.100.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 203.0.113.0/24 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 224.0.0.0/4 -j DROP
            iptables -A OUTPUT -o eth0 -m state ! --state ESTABLISHED -p udp -s 0/0 -d 240.0.0.0/4 -j DROP
          ''];
          securityContext.privileged = true;
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
        readinessProbe = {
          httpGet = {
            path = "/";
            port = 3000;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 30;
        };
      };

      pod.containers.status = {
        image = "gatehub/ethmonitor";
        requests.memory = "100Mi";
        limits.memory = "100Mi";
        requests.cpu = "20m";
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
