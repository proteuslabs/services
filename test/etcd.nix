{
  etcd = {
    require = import ../module-list.nix;

    kubernetes.namespaces.etcd = {};

    services.etcd = {
      enable = true;
      clusters.cluster1 = {};
    };
  };
}
