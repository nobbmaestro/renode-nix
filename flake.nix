{
  description = "Renode - Antmicro's open source simulation and virtual development framework for complex embedded systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" ];
      perSystem =
        { pkgs, ... }:
        let
          renode = pkgs.callPackage ./package.nix { };

          mkApp = name: description: {
            type = "app";
            program = "${renode}/bin/${name}";
            meta.description = description;
          };
        in
        {
          packages = {
            renode = renode;
            default = renode;
          };

          apps = rec {
            renode = mkApp "renode" "";
            renode-test = mkApp "renode-test" "";
            default = renode;
          };
        };

      flake = {
        overlays.default = final: prev: {
          renode = final.callPackage ./package.nix { };
        };
      };
    };
}
