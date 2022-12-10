{
  description = "concourse nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pnix.url = "github:polis-dev/pnix";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    lib = self.inputs.pnix.lib;
    fromPkgs = f:
      lib.eachSystemMap lib.defaultSystems (system:
        f (import nixpkgs {
          inherit system;
          overlays = builtins.attrValues self.overlays;
        }));
  in rec {
    # defines an overlay for using this flake via nixpkgs.
    overlays.default = final: prev: {
      concourse = prev.buildGo118Module rec {
        pname = "concourse";
        version = "7.9.0";
        vendorSha256 = "sha256-nX0r/7V+rgJb3/9O91QskYzBpWXIca7m3Do1QtGuHgg=";
        subPackages = ["cmd/concourse" "fly"];
        src = prev.fetchFromGitHub {
          owner = "concourse";
          repo = "concourse";
          rev = "v${version}";
          sha256 = "sha256-YatN0VG3oEUK+vzJzthRnX+EkvUgKq2uIunAoPMoRag=";
        };
        ldflags = ["-s" "-w" "-X github.com/concourse/concourse.Version=${version}"];
        doCheck = false;
        meta.description = "Concourse CI/CD system";
        meta.homepage = "https://github.com/concourse/concourse";
        overrideModAttrs = _: rec {
          CGO_ENABLED = "0";
          GO111MODULE = "on";
          GOPROXY = "direct";
          GOPRIVATE = "github.com/concourse";
          GOFLAGS = "-trimpath";
          GONOPROXY = GOPRIVATE;
          GONOSUMDB = GOPRIVATE;
        };
      };
    };
    # sets the formatter to be alejandra.
    formatter = fromPkgs (p: p.alejandra);
    # defines the package(s) exported by this flake.
    packages = fromPkgs (p: {
      inherit (p) concourse;
      default = p.concourse;
    });
    # defines the apps(s) exported by this flake.
    apps = lib.eachSystemMap lib.defaultSystems (system: rec {
      concourse = lib.mkApp {
        name = "concourse";
        drv = self.packages.${system}.default;
      };
      fly = lib.mkApp {
        name = "fly";
        drv = self.packages.${system}.default;
      };
      default = fly;
    });
    # the remainder ofthe file is dedicated to the nixOS module.
    nixosModules.default = {
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
          CONCOURSE_LOG_LEVEL = "debug";
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
    };
  };
}
