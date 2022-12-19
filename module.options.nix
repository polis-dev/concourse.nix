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
        default = self.packages.${config.nixpkgs.system}.default;
      };

      database = {
        auto = lib.mkEnableOption "auto-configure postgres for concourse?";
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
