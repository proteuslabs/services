{ config, lib, ... }:

with lib;

let
  cfg = config.services.openvpn;
in {
  options.services.openvpn = {
    enable = mkEnableOption "openvpn service";

    image = mkOption {
      description = "openvpn image to use";
      default = "offlinehacker/openvpn-k8s";
      type = types.str;
    };

    dh = mkOption {
      description = "Diffie-hellman file to use";
      type = types.path;
    };

    cert = mkOption {
      description = "Certificate to use in p12 format";
      type = types.path;
    };

    network = mkOption {
      description = "Network allocated to openvpn clients";
      type = types.str;
      default = "10.240.0.0";
    };

    subnet = mkOption {
      description = "Subnet to allocate to clients";
      type = types.str;
      default = "255.255.0.0";
    };

    proto = mkOption {
      description = "Protocol used by vpn clients";
      type = types.enum ["tcp" "udp"];
      default = "tcp";
    };

    natDevice = mkOption {
      description = "Device connected to kubernetes service network";
      type = types.str;
      default = "eth0";
    };

    serviceNetwork = mkOption {
      description = "Kubernetes service network";
      type = types.str;
    };

    serviceSubnet = mkOption {
      description = "Kubernetes service network subnet";
      type = types.str;
    };

    domain = mkOption {
      description = "Kubernetes domain";
      type = types.str;
      default = config.globals.internalDomain;
    };

    dns = mkOption {
      description = "Kubernetes dns server";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    kubernetes.deployments.openvpn = {
      dependencies = ["services/openvpn" "secrets/openvpn"];
      replicas = 2;
      pod.containers.nfs = {
        image = cfg.image;
        env = {
          OVPN_NETWORK = cfg.network;
          OVPN_SUBNET = cfg.subnet;
          OVPN_PROTO = cfg.proto;
          OVPN_NATDEVICE = cfg.natDevice;
          OVPN_K8S_SERVICE_NETWORK = cfg.serviceNetwork;
          OVPN_K8S_SERVICE_SUBNET = cfg.serviceSubnet;
          OVPN_K8S_DOMAIN = cfg.domain;
          OVPN_K8S_DNS = cfg.dns;
        };
        ports = [
          { name = "tcp"; port = 1194; protocol = "TCP"; }
        ];

        mounts = [{
          name = "openvpn";
          mountPath = "/etc/openvpn/pki";
        }];

        security.privileged = true;
      };

      pod.volumes.openvpn = {
        type = "secret";
        options.secretName = "openvpn";
      };
    };

    kubernetes.secrets.openvpn = {
      secrets."dh.pem" = cfg.dh;
      secrets."certs.p12" = cfg.cert;
    };

    kubernetes.services.openvpn = {
      ports = [{ port = 1194; }];
      type = "LoadBalancer";
    };
  };
}
