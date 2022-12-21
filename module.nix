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

    # builds a simple key-value environment file from the env attrset.
    mkEnvFile = name: attrs: let
      mkLine = name: value: "${name}=${builtins.toJSON value}";
      lines = lib.mapAttrsToList mkLine attrs;
      contents = "${builtins.concatStringsSep "\n" lines}\n";
    in
      builtins.toFile name contents;

    # builds the environment that systemd will load for concourse's
    # web/worker nodes.
    envFile = mkEnvFile "concourse.env" ({
        CONCOURSE_LOG_LEVEL = cfg.logLevel;
        CONCOURSE_ROOT_DIR = cfg.home;
      }
      // (lib.optionalAttrs cfg.worker.enable {
        IS_CONCOURSE_WORKER_NODE = "yes";
      })
      // (lib.optionalAttrs cfg.web.enable {
        IS_CONCOURSE_WEB_NODE = "yes";
        CONCOURSE_POSTGRES_HOST =
          if (cfg.db.host != "/run/postgresql")
          then cfg.db.host
          else "";
        CONCOURSE_POSTGRES_SOCKET =
          if (cfg.db.host == "/run/postgresql")
          then cfg.db.host
          else "";
        CONCOURSE_POSTGRES_PORT = cfg.db.port;
        CONCOURSE_POSTGRES_DATABASE = cfg.db.name;
        CONCOURSE_POSTGRES_USER = cfg.db.user;
        #CONCOURSE_SESSION_SIGNING_KEY=path/to/session_signing_key
        #CONCOURSE_TSA_HOST_KEY=path/to/tsa_host_key
        #CONCOURSE_TSA_AUTHORIZED_KEYS=path/to/authorized_worker_keys
        #CONCOURSE_ADD_LOCAL_USER=myuser:mypass
        #CONCOURSE_MAIN_TEAM_LOCAL_USER=myuser
      }));
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
        systemCallsList = ["@cpu-emulation" "@debug" "@keyring" "@ipc" "@mount" "@obsolete" "@privileged" "@setuid"];
        mkService = cond: {...} @ s:
          lib.mkIf cond
          (lib.mkMerge [
            s
            {
              path = lib.mkBefore [cfg.package];
              wantedBy = ["concourse.target"];
              serviceConfig = {
                EnvironmentFile = envFile;
                Group = cfg.group;
                LogsDirectory = "concourse";
                LogsDirectoryMode = "0750";
                Slice = "concourse.slice";
                StateDirectory = "concourse";
                StateDirectoryMode = "0750";
                UMask = "0027";
                User = cfg.user;
                WorkingDirectory = cfg.package;

                # Sandboxing
                CapabilityBoundingSet = "";
                NoNewPrivileges = true;
                ProcSubset = "pid";
                ProtectProc = "invisible";
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                PrivateUsers = true;
                ProtectClock = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectControlGroups = true;
                RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
                RestrictNamespaces = true;
                LockPersonality = true;
                MemoryDenyWriteExecute = false;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                RemoveIPC = true;
                PrivateMounts = true;

                # System Call Filtering
                SystemCallArchitectures = "native";
                SystemCallFilter = [("~" + builtins.concatStringsSep " " systemCallsList) "@chown" "pipe" "pipe2"];
                RuntimeDirectory = lib.mkDefault "concourse";
                RuntimeDirectoryMode = lib.mkDefault "0750";
              };
            }
          ]);
      in {
        slices.concourse.enable = true;
        targets.concourse.description = "All concourse services";

        services.concourse-init = mkService (cfg.worker.enable || cfg.web.enable) {
          description = "pre-flight setup for concourse workers/web nodes";
          after = ["network.target"];
          serviceConfig.Type = "oneshot";
          script = ''
            echo "Not fully implemented..."
          '';
        };

        services.concourse-web = mkService cfg.web.enable {
          description = "runs a concourse web node";
          requires = ["concourse-init.service"];
          after = ["network.target" "concourse-init.service"];

          serviceConfig = {
            RuntimeDirectory = "concourse-web";
            RuntimeDirectoryMode = "0750";
            Restart = "on-failure";
            RestartSec = 60;
          };

          environment = {
          };

          script = ''
            while true; do echo "Not implemented" && sleep 300; done
          '';
        };

        services.concourse-worker = mkService cfg.worker.enable {
          requires = ["concourse-init.service"];
          after = ["network.target" "concourse-init.service"];
          description = "runs a concourse worker node";
          serviceConfig = {
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
