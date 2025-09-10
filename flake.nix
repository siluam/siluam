{
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  outputs = { ... }:
    let
      siluam = {
        lib = import ./lib.nix;
        # TODO: Add the legacyPackages and pkgs here
      };
    in { __functor = self: import ./.; } // siluam;
}
