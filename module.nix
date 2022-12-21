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
    mkEnvFile = name: attrs: let
      mkLine = name: value: "${name}=\"${toString value}\"";
      lines = lib.mapAttrsToList mkLine attrs;
      contents = builtins.concatStringsSep "\n" lines;
    in
      builtins.toFile name contents;

    envFile = mkEnvFile "concourse.env" env;
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

      systemd = let 
        WorkingDirectory = cfg.package;
        Slice = "concourse.slice";
        environment = env;
        path = [
          cfg.package
          pkgs.coreutils
          pkgs.jq
          config.nix.package.out
        ];
      in {
        slices.concourse.enable = true;
        targets.concourse.description = "All concourse services";

        services.concourse-init = {
          description = "pre-flight setup for concourse workers/web nodes";
          inherit environment path;
          after = ["network.target"];
          wantedBy = ["concourse.target"];

          serviceConfig = {
            Type = "oneshot";
            inherit Slice WorkingDirectory;
          };

          script = ''
            echo "Not fully implemented..."
          '';
        };

        services.concourse-web = {
          description = "runs a concourse web node";
          requires = ["concourse-init.service"];
          after = ["network.target" "concourse-init.service"];
          wantedBy = ["concourse.target"];
          inherit environment path;

          serviceConfig = {
            inherit WorkingDirectory Slice;
            RuntimeDirectory = "concourse-web";
            RuntimeDirectoryMode = "0750";
            Restart = "on-failure";
            RestartSec = 60;
          };

          script = ''
            while true; do echo "Not implemented" && sleep 300; done
          '';
        };

        services.concourse-worker = {
          wantedBy = ["concourse.target"];
          requires = ["concourse-init.service"];
          after = ["network.target" "concourse-init.service"];
          description = "runs a concourse worker node";
          inherit environment path;

          serviceConfig = {
            inherit WorkingDirectory Slice;
            Restart = "on-failure";
            RestartSec = 60;
            RuntimeDirectory = "concourse-worker";
            RuntimeDirectoryMode = "0750";
          };

          script = ''
            while true; do echo "Not implemented" && sleep 300; done
          '';
        };
      };
    };
}
