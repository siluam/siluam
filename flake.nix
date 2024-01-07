{
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  outputs = { ... }:
    let siluam = { lib = import ./lib.nix; };
    in { __functor = self: import ./.; } // siluam;
}
