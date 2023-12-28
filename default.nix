src:
with import ./lib.nix;
let
  flake = mkFlake { inherit src; };
  nixpkgs = flake.inputs.nixpkgs or (mkFlake {
    inherit src;
    owner = "nixos";
    repo = "nixpkgs";
  });
  inherit (nixpkgs) lib;
  flakeAttrs = lib.filterAttrs (n: isAttrsOnly) flake;
  swap = system: builtins.mapAttrs (n: builtins.getAttr system) flakeAttrs;
  assign = system:
    builtins.mapAttrs (n: v: v // { currentSystem = v.${system}; })
    (lib.filterAttrs (n: builtins.hasAttr system) flakeAttrs);
  assignPkgs = current: attrs:
    attrs // (let
      inherit (nixpkgs) legacyPackages;
      pkgs = if current then
        legacyPackages.${currentSystem}
      else
        (legacyPackages // {
          currentSystem = legacyPackages.${currentSystem};
        });
    in {
      ${if (attrs ? legacyPackages) then null else "legacyPackages"} = pkgs;
      ${if (attrs ? pkgs) then null else "pkgs"} = pkgs;
      ${if (attrs ? lib) then null else "lib"} = lib;
    });
in flake // {
  currentSystem = assignPkgs true
    (flake.${builtins.currentSystem} or (swap builtins.currentSystem));
} // (assignPkgs false (assign builtins.currentSystem))
