{
  config,
  lib,
  pkgs,
  options,
  ...
}: {
  # define the options that an end-user might want to configure.
  options = {
    services.concourse = {
      enable = lib.mkEnableOption "enable concourse CI/CD service?";

      user = lib.mkOption {
        description = lib.mdDoc "user under which concourse runs";
        type = lib.types.str;
        default = "concourse";
      };

      home = lib.mkOption {
        description = lib.mdDoc "user's home directory";
        type = lib.types.str;
        default = "/var/lib/concourse";
      };

      secretsFile = lib.mkOption {
        description = lib.mdDoc "path to secrets file";
        type = lib.types.str;
        default = "/var/lib/concourse/secrets.env";
      };

      group = lib.mkOption {
        description = lib.mdDoc "Group under which concourse runs.";
        type = lib.types.str;
        default = "concourse";
      };

      logLevel = lib.mkOption {
        description = lib.mdDoc "log level";
        type = lib.types.enum ["debug" "info" "warn" "trace"];
        default = "debug";
      };

      package = lib.mkOption {
        type = lib.types.package;
        defaultText = lib.literalExpression "pkgs.concourse";
        description = lib.mdDoc "relevant package to use.";
        default = pkgs.concourse;
      };

      db = {
        auto = lib.mkOption {
          description = lib.mdDoc "automatically setup (local) postgres server for concourse?";
          type = lib.types.bool;
          default = true;
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "/run/postgresql";
          example = "10.55.55.55";
          description = lib.mdDoc "postgres host address or unix socket.";
        };

        port = lib.mkOption {
          type = lib.types.int;
          default = 5432;
          description = lib.mdDoc "postgres host port.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "concourse";
          description = lib.mdDoc "postgres database name.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "concourse";
          description = lib.mdDoc "postgres database user.";
        };

        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/var/lib/concourse/secrets/db-password";
          example = "/run/keys/concourse-db-password";
          description = lib.mdDoc ''
            A file containing the password corresponding to
            {option}`database.user`.
          '';
        };
      };

      web = {
        enable = lib.mkEnableOption "is this a concourse web node?";
        port = lib.mkOption {
          description = lib.mdDoc "TCP port used by the concourse web service.";
          type = lib.types.port;
          default = 8080;
        };
      };

      worker = {
        enable = lib.mkEnableOption "is this a concourse worker node?";
      };
    };
  };
}
