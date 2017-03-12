{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.taskd;
in {
  options.services.taskd = {
    enable = mkEnableOption "taskd service";

    image = mkOption {
      description = "NFS image to use";
      default = "vimagick/taskd";
      type = types.str;
    };

    vars = mkOption {
      description = "Cert generation vars";
      default = ''
        BITS=4096
        EXPIRATION_DAYS=365
        ORGANIZATION="X-Truder"
        CN=taskd.x-truder.net
        COUNTRY=SL
        STATE="Slovenia"
        LOCALITY="Slovenian"
      '';
    };

    config = mkOption {
      description = "Taskd configuration";
      type = types.lines;
      default = ''
        confirmation=1
        extensions=/usr/libexec/taskd
        ip.log=on
        log=/dev/stdout
        pid.file=/run/taskd.pid
        queue.size=10
        request.limit=1048576
        root=/var/taskd
        server=0.0.0.0:53589
        trust=strict
        verbose=1
        client.cert=/var/taskd/client.cert.pem
        client.key=/var/taskd/client.key.pem
        server.cert=/var/taskd/server.cert.pem
        server.key=/var/taskd/server.key.pem
        server.crl=/var/taskd/server.crl.pem
        ca.cert=/var/taskd/ca.cert.pem
      '';
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.taskd = {
      dependencies = ["services/taskd" "secrets/taskd" "pvc/taskd"];

      pod.annotations."pod.beta.kubernetes.io/init-containers" = builtins.toJSON [{
        name = "init";
        image = cfg.image;
        command = ["/bin/sh" "-c" ''
          apk update
          apk add wget openssl tar ca-certificates gnutls-utils

          cd /var/taskd
          cp /etc/taskd/config .
          mkdir -p /var/taskd/orgs
          mkdir -p /var/taskd/users

          if [ ! -d "/var/taskd/pki" ]; then
            wget -O- http://taskwarrior.org/download/taskd-1.1.0.tar.gz | tar xvz --strip 1 taskd-1.1.0/pki
            cd pki
            cp /etc/taskd/vars .
            ./generate
            mv *.pem ../
          fi
        ''];
        volumeMounts = [{
          name = "storage";
          mountPath = "/var/taskd";
        } {
          name = "config";
          mountPath = "/etc/taskd";
        }];
      }];
      pod.containers.taskd = {
        image = cfg.image;
        ports = [
          { name = "tcp"; port = 53589; protocol = "TCP"; }
        ];
        mounts = [{
          name = "storage";
          mountPath = "/var/taskd";
        }];
      };

      pod.volumes.storage = {
        type = "persistentVolumeClaim";
        options.claimName = "taskd";
      };
      pod.volumes.config = {
        type = "secret";
        options.secretName = "taskd";
      };
    };

    kubernetes.secrets.taskd = {
      secrets.config = pkgs.writeText "config" cfg.config;
      secrets.vars = pkgs.writeText "vars" cfg.vars;
    };

    kubernetes.pvc.taskd.size = "1G";

    kubernetes.services.taskd.ports = [{
      port = 53589;
      targetPort = 53589;
      nodePort = 32763;
    }];
    kubernetes.services.taskd.type = "NodePort";
  };
}
