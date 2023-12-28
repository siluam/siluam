{
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  outputs = { ... }: { lib = import ./lib.nix; };
}
