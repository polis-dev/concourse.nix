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
    nixosModules.default = import ./module.nix;
    overlays.default = import ./overlay.nix;

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
      default = concourse;
    });
  };
}
