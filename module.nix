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

      web.port = lib.mkOption {
        description = lib.mdDoc "TCP port used by the concourse web service.";
        type = lib.types.port;
        default = 8080;
      };
    };
  };
  # utilise the defined options for this module to configure concourse.
  config = let
    # cfg represents the current configuration at the time of rebuild.
    cfg = config.services.concourse;
    # env represents the (shared) environment as it will be presented to
    # concourse by systemd.
    env = {
      CONCOURSE_LOG_LEVEL = cfg.logLevel;
    };

    envFileLines = lib.concatLists (lib.mapAttrsToList (name: value: (lib.optionals (value != null) ["${name}=\"${toString value}\""])) env);
    envFile = builtins.toFile "concourse.env" (lib.concatMapStrings (s: s + "\n") envFileLines);
    envLoader = pkgs.writeShellScriptBin "concourseEnvLoader" ''
      set -a
      export CONCOURSE_ROOT="${cfg.package}"
      source "${envFile}"
      source "${cfg.secretsFile}"
      eval -- "\$@"
    '';
  in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.enable -> (cfg.user != null);
          message = "<option>services.concourse.user</option> needs to be set if <option>services.concourse</option> is enabled.";
        }
      ];

      users = {
        groups."${cfg.group}" = {};
        users."${cfg.user}" = {
          isSystemUser = true;
          home = cfg.package;
          inherit (cfg) group;
          packages = [cfg.package envLoader];
        };
      };
    };
}
