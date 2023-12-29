{
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  outputs = { ... }: { lib = import ./lib.nix; };
}
