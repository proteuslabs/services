{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rippled;

  rippledConfig = ''
[server]
port_peer
port_rpc
port_ws_public

[port_peer]
ip=0.0.0.0
port=${toString cfg.peerPort}
protocol=peer
admin=127.0.0.1

[port_rpc]
ip=127.0.0.1
port=5005
protocol=http
admin=127.0.0.1

[port_ws_public]
ip=0.0.0.0
port=5006
protocol=ws,wss
admin=127.0.0.1

[database_path]
/data

[node_db]
type=rocksdb
path=/data
compression=1
online_delete=48000
advisory_delete=0
open_files=2000
filter_bits=12
cache_mb=256
file_size_mb=8
file_size_mult=2

[ips]
r.ripple.com 51235

[validators]
n949f75evCHwgyP4fPVgaHqNHxUVN15PsJEZ3B3HnXPcPjcZAoy7  RL1
n9MD5h24qrQqiyBC8aeqqCWvpiBiYQ3jxSr91uiDvmrkyHRdYLUj  RL2
n9L81uNCaPgtUJfaHh89gmdvXKAmSt5Gdsw2g1iPWaPkAHW5Nm4C  RL3
n9KiYM9CgngLvtRCQHZwgC2gjpdaZcCcbt3VboxiNFcKuwFVujzS  RL4
n9LdgEtkmGB9E2h3K4Vp7iGUaKuq23Zr32ehxiU8FWY7xoxbWTSA  RL5

${optionalString (cfg.validationSeed != null) ''
[validation_seed]
${cfg.validationSeed}
''}

[node_size]
${cfg.nodeSize}

[ledger_history]
12400

[fetch_depth]
full

[validation_quorum]
3

[sntp_servers]
time.windows.com
time.apple.com
time.nist.gov
pool.ntp.org

[rpc_startup]
{ "command": "log_level", "severity": "error" }

${cfg.extraConfig}
  '';
in {
  options.services.rippled = {
    enable = mkEnableOption "redis service";

    replicas = mkOption {
      description = "Ripple replicas";
      type = types.int;
      default = 3;
    };

    storage = {
      size = mkOption {
        description = "Rippled storage size";
        default = "69G";
        type = types.str;
      };

      class = mkOption {
        description = "Rippled storage class";
        default = "default";
        type = types.str;
      };
    };

    nodeSize = mkOption {
      description = "Rippled node size";
      default = "large";
      type = types.enum ["small" "medium" "large"];
    };

    validationSeed = mkOption {
      description = "Rippled validation seed";
      default = null;
      type = types.nullOr types.str;
    };

    peerPort = mkOption {
      description = "Rippled peer port";
      default = 32235;
      type = types.int;
    };

    extraConfig = mkOption {
      description = "Extra rippled config";
      default = "";
      type = types.lines;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.statefulSets.rippled = {
      replicas = cfg.replicas;
      podManagementPolicy = "Parallel";

      dependencies = ["services/rippled" "secrets/rippled-config"];

      # schedule one pod on one node
      pod.annotations."scheduler.alpha.kubernetes.io/affinity" =
        builtins.toJSON {
          podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
            labelSelector = {
              matchExpressions = [{
                key = "name";
                operator = "In";
                values = ["rippled"];
              }];
            };
            topologyKey = "kubernetes.io/hostname";
          }];
        };

      pod.containers.rippled = {
        image = "gatehub/rippled";
        command = ["/opt/ripple/bin/rippled" "--conf" "/etc/rippled/rippled.conf"];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        } {
          name = "config";
          mountPath = "/etc/rippled";
        }];
        ports = [{ port = 5006; } { port = 51235; }];
        requests.memory = "16000Mi";
        requests.cpu = "2000m";
        limits.memory = "16000Mi";

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
        image = "gatehub/rippledmonitor";
        imagePullPolicy = "IfNotPresent";

        requests.memory = "100Mi";
        limits.memory = "100Mi";
        requests.cpu = "20m";
      };

      pod.volumes.config = {
        type = "secret";
        options.secretName = "rippled-config";
      };

      volumeClaimTemplates.storage= {
        size = cfg.storage.size;
        storageClassName = cfg.storage.class;
      };
    };

    kubernetes.secrets.rippled-config = {
      secrets."rippled.conf" = pkgs.writeText "rippled.conf" rippledConfig;
    };

    kubernetes.services.rippled = {
      type = "NodePort";
      ports = [{
        name = "websockets-alt";
        port = 5006;
      } {
        name = "websockets";
        port = 443;
        targetPort = 5006;
      } {
        name = "p2p";
        port = cfg.peerPort;
        nodePort = cfg.peerPort;
      }];
    };
  };
}
