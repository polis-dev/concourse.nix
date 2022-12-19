{
  config,
  lib,
  pkgs,
  options,
  ...
}: {
  # options are in their own file for clarity/visibility.
  imports = [./module.options.nix];
  # utilise the defined options for this module to configure concourse.
  config = let
    # cfg represents the current configuration at the time of rebuild.
    cfg = config.services.concourse;
    # env represents the (shared) environment as it will be presented to
    # concourse by systemd.
    env.CONCOURSE_LOG_LEVEL = cfg.logLevel;
    env.CONCOURSE_ROOT_DIR = cfg.home;

    # builds a simple key-value environment file from the env attrset.
    envFile =
      builtins.toFile "concourse.env" (lib.concatMapStrings (s: s + "\n") lib.concatLists
        (lib.mapAttrsToList (name: value: (lib.optionals (value != null) ["${name}=\"${toString value}\""])) env));
  in
    lib.mkIf cfg.enable {
      assertions = lib.mapAttrsToList (message: assertion: {inherit assertion message;}) {
        "<option>services.concourse.user</option> needs to be set if <option>services.concourse</option> is enabled." =
          cfg.enable -> (cfg.user != null);
      };
      users = {
        groups."${cfg.group}" = {};
        users."${cfg.user}" = {
          inherit (cfg) home group;
          isSystemUser = true;
          packages = [
            cfg.package
            (pkgs.writeShellScriptBin "concourseEnvLoader" ''
              # load secrets from our envFile and secretsFile into the env.
              set -a && source "${envFile}" && source "${cfg.secretsFile}" && set +a
              eval -- "\$@"
            '')
          ];
        };
      };
    };
}
