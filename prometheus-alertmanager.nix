{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.prometheus-alertmanager;

  routeOptions = {
    receiver = mkOption {
      description = "Which prometheus alertmanager receiver to use";
      type = types.str;
    };

    groupBy = mkOption {
      description = "Group by alerts by field";
      default = [];
      type = types.listOf types.str;
    };

    continue = mkOption {
      description = "Whether an alert should continue matching subsequent sibling nodes";
      default = false;
      type = types.bool;
    };

    match = mkOption {
      description = "A set of equality matchers an alert has to fulfill to match the node";
      type = types.attrsOf types.str;
      default = {};
    };

    matchRe = mkOption {
      description = "A set of regex-matchers an alert has to fulfill to match the node.";
      type = types.attrsOf types.str;
      default = {};
    };

    groupWait = mkOption {
      description = "How long to initially wait to send a notification for a group of alerts.";
      type = types.str;
      default = "10s";
    };

    groupInterval = mkOption {
      description = ''
        How long to wait before sending a notification about new alerts that
        are added to a group of alerts for which an initial notification has
        already been sent. (Usually ~5min or more.)
      '';
      type = types.str;
      default = "5m";
    };

    repeatInterval = mkOption {
      description = ''
        How long to wait before sending a notification again if it has already
        been sent successfully for an alert. (Usually ~3h or more).
      '';
      type = types.str;
      default = "3h";
    };

    routes = mkOption {
      type = types.attrsOf (types.submodule routeOptions);
      description = "Child routes";
      default = {};
    };
  };

  mkRoute = cfg: {
    receiver = cfg.receiver;
    group_by = cfg.groupBy;
    continue = cfg.continue;
    match = cfg.match;
    match_re = cfg.matchRe;
    group_wait = cfg.groupWait;
    group_interval = cfg.groupInterval;
    repeat_interval = cfg.repeatInterval;
    routes = mapAttrsToList (name: route: mkRoute route) cfg.routes;
  };

  mkInhibitRule = cfg: {
    target_match = cfg.targetMatch;
    target_match_re = cfg.targetMatchRe;
    source_match = cfg.sourceMatch;
    source_match_re = cfg.sourceMatchRe;
    equal = cfg.equal;
  };

  mkReceiver = cfg: {
    name = cfg.name;
    "${cfg.type}_configs" = [cfg.options];
  };

  alertmanagerConfig = {
    global = {
      resolve_timeout = cfg.resolveTimeout;
    };
    route = mkRoute cfg.route;
    receivers = mapAttrsToList (name: value: mkReceiver value) cfg.receivers;
    inhibit_rules = mapAttrsToList (name: value: mkInhibitRule value) cfg.inhibitRules;
    templates = cfg.templates;
  };
in {
  options.services.prometheus-alertmanager = {
    enable = mkEnableOption "prometheus alertmanager server";

    version = mkOption {
      description = "Prometheus alertmanager server version";
      type = types.str;
      default = "v0.7.1";
    };

    resolveTimeout = mkOption {
      description = ''
        ResolveTimeout is the time after which an alert is declared resolved
        if it has not been updated.
      '';
      type = types.str;
      default = "5m";
    };

    receivers = mkOption {
      description = "Prometheus receivers";
      type = types.attrsOf (types.submodule ({name, config, ... }: {
        options = {
          name = mkOption {
            description = "Unique name of the receiver";
            type = types.str;
            default = name;
          };

          type = mkOption {
            description = "Receiver name (defaults to attr name)";
            type = types.enum ["email" "hipchat" "pagerduty" "pushover" "slack" "opsgenie" "webhook"];
          };

          options = mkOption {
            description = "Reciver options";
            type = types.attrs;
            default = {};
            example = literalExample ''
              {
                room_id = "System notiffications";
                auth_token = "token";
              }
            '';
          };
        };
      }));
    };

    route = routeOptions;

    inhibitRules = mkOption {
      description = "Attribute set of alertmanager inhibit rules";
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          targetMatch = mkOption {
            description = "Matchers that have to be fulfilled in the alerts to be muted";
            type = types.attrsOf types.str;
            default = {};
          };

          targetMatchRe = mkOption {
            description = "Regex matchers that have to be fulfilled in the alerts to be muted";
            type = types.attrsOf types.str;
            default = {};
          };

          sourceMatch = mkOption {
            description = "Matchers for which one or more alerts have to exist for the inhibition to take effect.";
            type = types.attrsOf types.str;
            default = {};
          };

          sourceMatchRe = mkOption {
            description = "Regex matchers for which one or more alerts have to exist for the inhibition to take effect.";
            type = types.attrsOf types.str;
            default = {};
          };

          equal = mkOption {
            description = "Labels that must have an equal value in the source and target alert for the inhibition to take effect.";
            type = types.listOf types.str;
            default = [];
          };
        };
      });
    };

    templates = mkOption {
      description = ''
				Files from which custom notification template definitions are read.
        The last component may use a wildcard matcher, e.g. 'templates/*.tmpl'.
      '';
      type = types.listOf types.path;
      default = [];
    };

    storage = {
      size = mkOption {
        description = "Prometheus alertmanager storage size";
        default = "2Gi";
        type = types.str;
      };
    };

    extraArgs = mkOption {
      description = "Prometheus server additional options";
      default = [];
      type = types.listOf types.str;
    };

    extraConfig = mkOption {
      description = "Prometheus extra config";
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    kubernetes.statefulSets.prometheus-alertmanager = {
      dependencies = [
        "configmaps/prometheus-alertmanager"
        "services/prometheus-alertmanager"
      ];

      # schedule one pod on one node
      pod.annotations."scheduler.alpha.kubernetes.io/affinity" =
        builtins.toJSON {
          podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
            labelSelector = {
              matchExpressions = [{
                key = "name";
                operator = "In";
                values = ["prometheus-alertmanager"];
              }];
            };
            topologyKey = "kubernetes.io/hostname";
          }];
        };

      replicas = mkDefault 2;

      # reloads alertmanager configuration
      pod.containers.server-reload = {
        image = "jimmidyson/configmap-reload:v0.1";
        args = [
          "--volume-dir=/etc/config"
          "--webhook-url=http://localhost:9093/-/reload"
        ];
        mounts = [{
          name = "config";
          mountPath = "/etc/config";
          readOnly = true;
        }];
      };

      # prometheus alertmanager
      pod.containers.alertmanager = {
        image = "prom/alertmanager:${cfg.version}";
        args = [
          "--config.file=/etc/config/alertmanager.json"
          "--storage.path=/data"
        ] ++ cfg.extraArgs;
        ports = [{ port = 9093; }];
        mounts = [{
          name = "storage";
          mountPath = "/data";
        } {
          name = "config";
          mountPath = "/etc/config";
          readOnly = true;
        }];
        livenessProbe = {
          httpGet = {
            path = "/";
            port = 9093;
          };
          initialDelaySeconds = 30;
          timeoutSeconds = 30;
        };
      };
      pod.volumes.config = {
        type = "configMap";
        options.name = "prometheus-alertmanager";
      };

      volumeClaimTemplates.storage = {
        size = cfg.storage.size;
      };
    };

    kubernetes.configMaps.prometheus-alertmanager.data."alertmanager.json" =
      (builtins.toJSON alertmanagerConfig);

    kubernetes.services.prometheus-alertmanager = {
      ports = [{
        port = 9093;
      }];
    };
  };
}
