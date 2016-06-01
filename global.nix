{ config, lib, ...}:

with lib;

{
  options.globals = {
    domain = mkOption {
      description = "Company domain name";
      type = types.str;
    };

    registry = mkOption {
      description = "Url of docker private registry";
      type = types.str;
    };

    internalDomain = mkOption {
      description = "Namespace internal domain";
      type = types.str;
      default = "${config.kubernetes.namespace.name}.svc.cluster.local";
    };

    email = mkOption {
      description = "Sending email";
      type = types.str;
    };

    replyEmail = mkOption {
      description = "Reply email";
      type = types.str;
    };

    timezone = mkOption {
      description = "Timezone you are in";
      type = types.str;
      example = "Europe/Ljubljana";
    };

    smtp = {
      domain = mkOption {
        description = "SMTP domain";
        type = types.str;
        default = config.globals.domain;
      };

      host = mkOption {
        description = "SMTP host";
        type = types.str;
      };

      port = mkOption {
        description = "SMTP port";
        type = types.int;
        default = 587;
      };

      user = mkOption {
        description = "SMTP user";
        type = types.str;
      };

      pass = mkOption {
        description = "SMTP password";
        type = types.str;
      };

      tls = mkOption {
        description = "Whether to enable smtp tls";
        type = types.bool;
        default = true;
      };
    };
  };
}
