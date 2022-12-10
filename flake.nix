{
  description = "concourse nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    pnix.url = "github:polis-dev/pnix";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: rec {
    lib = self.inputs.pnix.lib;
    # defines an overlay for using this flake via nixpkgs.
    overlays.default = final: prev: {concourse = (self.packages.${prev.system}).default;};
    # sets the formatter to be alejandra.
    formatter = self.lib.eachSystemMap self.lib.defaultSystems (system: (import nixpkgs {inherit system;}).alejandra);
    # defines the package(s) exported by this flake.
    packages = self.lib.eachSystemMap self.lib.defaultSystems (system:
      with (import nixpkgs {inherit system;}); {
        default = buildGo118Module rec {
          pname = "concourse";
          version = "7.9.0";
          vendorSha256 = "sha256-nX0r/7V+rgJb3/9O91QskYzBpWXIca7m3Do1QtGuHgg=";
          subPackages = ["cmd/concourse" "fly"];
          src = fetchFromGitHub {
            owner = "concourse";
            repo = "concourse";
            rev = "v${version}";
            sha256 = "sha256-YatN0VG3oEUK+vzJzthRnX+EkvUgKq2uIunAoPMoRag=";
          };
          ldflags = ["-s" "-w"];
          doCheck = false;
          meta.description = "Concourse CI/CD system";
          meta.homepage = "https://github.com/concourse/concourse";
          meta.maintainers = with lib.maintainers; [jakelogemann];
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
      });

    nixosModules.default = {
      config,
      lib,
      pkgs,
      options,
      ...
    }: {
      /*
      Concourse Service Configuration Options
      */
      options.services.concourse = {
        enable = lib.mkEnableOption "enable concourse CI/CD service?";

        package = lib.mkOption {
          type = lib.types.package;
          defaultText = lib.literalExpression "pkgs.concourse";
          description = lib.mdDoc "relevant package to use.";
          default = self.packages.${config.nixpkgs.system}.default;
        };
      };
      /*
      Concourse Configuration
      */
      config = let
        concourse = config.services.concourse;
      in
        lib.mkIf concourse.enable {
          environment.systemPackages = [concourse.package];
        };
    };
    /*
    example usage in NixOS
    */
    nixosConfigurations.default = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      specialArgs = {inherit nixpkgs system self;};
      modules = [
        self.nixosModules.default
        ({
          config,
          lib,
          pkgs,
          ...
        }: {
          services.concourse = {
            enable = true;
          };
        })
      ];
    };
  };
}
