{ config, lib, ... }:

with lib;

let
  cfg = config.services.zookeeper;
in {
  options.services.zookeeper = {
    enable = mkEnableOption "zookeeper";

    replicas = mkOption {
      description = "Number of zookeeper replicas";
      default = 3;
      type = types.int;
    };

    memorySize = mkOption {
      description = "Zookeeper memory size";
      default = "2Gi";
      type = types.str;
    };

    heapSize = mkOption {
      description = "Zookeeper heap size";
      default = "1G";
      type = types.str;
    };

    tickTime = mkOption {
      type = types.int;
      description = ''
        The length of a single tick, which is the basic time unit used by ZooKeeper,
        as measured in milliseconds. It is used to regulate heartbeats, and timeouts.
        For example, the minimum session timeout will be two ticks.
      '';
      default = 2000;
    };

    initTicks = mkOption {
      type = types.int;
      description = ''
				Amount of time, in ticks, to allow followers to connect
				and sync to a leader. Increased this value as needed, if the amount of
				data managed by ZooKeeper is large.
      '';
      default = 10;
    };

    syncTicks = mkOption {
      type = types.int;
      description = ''
        Amount of time, in ticks, to allow followers to sync with ZooKeeper.
        If followers fall too far behind a leader, they will be dropped.
      '';
      default = 5;
    };

    maxClientCnxns = mkOption {
      type = types.int;
      description = ''
        Limits the number of concurrent connections (at the socket level) that
        a single client, identified by IP address, may make to a single member
        of the ZooKeeper ensemble. This is used to prevent certain classes of
        DoS attacks, including file descriptor exhaustion. Setting this to 0 or
        omitting it entirely removes the limit on concurrent connections.
      '';
      default = 60;
    };

    snapRetainCount = mkOption {
      type = types.int;
      description = ''
        When enabled, ZooKeeper auto purge feature retains the
        autopurge.snapRetainCount most recent snapshots and the corresponding
        transaction logs in the dataDir and dataLogDir respectively and deletes the rest.
      '';
      default = 3;
    };

    purgeHours = mkOption {
      type = types.int;
      description = ''
        The time interval in hours for which the purge task has to be triggered.
        Set to a positive integer (1 and above) to enable the auto purging.
      '';
      default = 3;
    };

    logLevel = mkOption {
      type = types.enum ["INFO" "DEBUG"];
      description = "ZooKeeper log level";
      default = "INFO";
    };

    storage = {
      size = mkOption {
        description = "ZooKeeper storage size";
        type = types.str;
        default = "50Gi";
      };

      class = mkOption {
        description = "ZooKeeper storage class";
        type = types.str;
        default = "default";
      };
    };
  };

  config = mkIf cfg.enable {
    kubernetes.statefulSets.zookeeper = {
      dependencies = [
        "services/zookeeper"
        "services/zookeeper-hsvc"
      ];

      serviceName = "zookeeper-hsvc";

      replicas = cfg.replicas;

      pod.securityContext = {
        runAsUser = 1000;
        fsGroup = 1000;
      };

      # schedule one pod on one node
      pod.annotations."scheduler.alpha.kubernetes.io/affinity" =
        builtins.toJSON {
          podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
            labelSelector = {
              matchExpressions = [{
                key = "name";
                operator = "In";
                values = ["zookeeper"];
              }];
            };
            topologyKey = "kubernetes.io/hostname";
          }];
        };

      pod.containers.zookeeper = {
        image = "gcr.io/google_samples/k8szk:v2";

        command = ["sh" "-c" "zkGenConfig.sh && exec zkServer.sh start-foreground"];

        env = {
          ZK_REPLICAS = cfg.replicas;
          ZK_HEAP_SIZE = cfg.heapSize;
          ZK_TICK_TIME = cfg.tickTime;
          ZK_INIT_LIMIT = cfg.initTicks;
          ZK_SYNC_LIMIT = cfg.syncTicks;
          ZK_MAX_CLIENT_CNXNS = cfg.maxClientCnxns;
          ZK_SNAP_RETAIN_COUNT = cfg.snapRetainCount;
          ZK_PURGE_INTERVAL = cfg.purgeHours;
          ZK_LOG_LEVEL = cfg.logLevel;
          ZK_CLIENT_PORT = 2181;
          ZK_SERVER_PORT = 2888;
          ZK_ELECTION_PORT = 3888;
        };

        requests = {
          memory = cfg.memorySize;
          cpu = "200m";
        };

        livenessProbe = {
          exec.command = ["zkOk.sh"];
          initialDelaySeconds = 15;
          timeoutSeconds = 5;
        };

        readinessProbe = {
          exec.command = ["zkOk.sh"];
          initialDelaySeconds = 15;
          timeoutSeconds = 5;
        };

        ports = [
          {name = "client"; port = 2181;}
          {name = "server"; port = 2888;}
          {name = "leader-election"; port = 3888;}
        ];

        mounts = [{
          name = "storage";
          mountPath = "/var/lib/zookeeper";
        }];
      };

      pod.containers.zookeeper-metrics = {
        image = "xtruder/zk_exporter";
        requests = {
          memory = "50Mi";
          cpu = "50m";
        };
        ports = [{name = "metrics"; port = 9141;}];
      };

      volumeClaimTemplates.storage = {
        size = cfg.storage.size;
        storageClassName = cfg.storage.class;
      };
    };

    kubernetes.services.zookeeper-hsvc = {
      annotations = {
        "prometheus.io/scrape" = "true";
        "prometheus.io/port" = "9141";
      };
      clusterIP = "None";
      ports = [{
        name = "server";
        port = 2888;
      } {
        name = "metrics";
        port = 9141;
      } {
        name = "leader-election";
        port = 3888;
      }];
      selector.name = "zookeeper";
    };

    kubernetes.services.zookeeper = {
      ports = [{
        name = "client";
        port = 2181;
      }];
    };

    kubernetes.podDistributionBudgets.zookeeper.minAvailable = "60%";
  };
}
