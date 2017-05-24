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
port=51236
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

[node_size]
medium

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

    storageSize = mkOption {
      description = "Rippled storage size";
      default = "100G";
      type = types.str;
    };

    count = mkOption {
      description = "Number of rippled servers";
      type = types.int;
      default = 2;
    };

    extraConfig = mkOption {
      description = "Extra rippled config";
      default = "";
      type = types.lines;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments = listToAttrs (map (i: nameValuePair "rippled-${toString i}" {
      labels.app = "rippled";

      dependencies = ["services/rippled" "pvc/rippled-${toString i}" "secrets/rippled-config"];

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
        requests.memory = "6000Mi";
        requests.cpu = "1500m";
      };

      pod.volumes.config = {
        type = "secret";
        options.secretName = "rippled-config";
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "rippled-${toString i}";
      };
    }) (range 0 (cfg.count - 1)));

    kubernetes.pvc = listToAttrs (map (i: nameValuePair "rippled-${toString i}"  {
      annotations."volume.beta.kubernetes.io/storage-class" = "fast";
      name = "rippled-${toString i}";
      size = "100G";
    }) (range 0 (cfg.count - 1)));

    kubernetes.secrets.rippled-config = {
      secrets."rippled.conf" = pkgs.writeText "rippled.conf" rippledConfig;
    };

    kubernetes.services.rippled = {
      selector.app = "rippled";
      ports = [{
        name = "websockets-alt";
        port = 5006;
      } {
        name = "websockets";
        port = 443;
        targetPort = 5006;
      } {
        name = "p2p";
        port = 51235;
      }];
    };
  };
}