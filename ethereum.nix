{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ethereum;
in {
  options.services.ethereum = {
    enable = mkOption {
      description = "Wheter to enable ethereum";
      type = types.bool;
      default = false;
    };

    image = mkOption {
      description = "Name of the image";
      type = types.str;
      default = "ethereum/client-go:alpine";
    };
  };

  config = mkIf cfg.enable {
    kubernetes.controllers.ethereum = {
      dependencies = ["services/ethereum" "pvc/ethereum"];
      pod.containers.ethereum = {
        image = cfg.image;
        command = ["/geth" "--testnet" "--rpc" "--rpcport" "8545" "--rpcaddr" "0.0.0.0" "--rpccorsdomain" "*" "--port" "30303" "--ipcapi" "admin,db,eth,debug,miner,net,shh,txpool,personal,web3" "--rpcapi" "admin,db,eth,debug,miner,net,shh,txpool,personal,web3"];
        #ports = [{ name = "lala" ; port = 30303; } { name = "lili" ; port = 8545; }];
        mounts = [{
          name = "storage";
          mountPath = "/root";
        }];

      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "ethereum";
      };
    };

  kubernetes.services.ethereum.ports = [{ name = "mgmt"; port = 30303; } { name = "migt"; port = 8545; }];
  kubernetes.pvc.ethereum.size = "100G";
  };
}
