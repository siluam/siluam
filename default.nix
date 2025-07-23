let
  siluam = src:
    with import ./lib.nix;
    let
      self = mkFlake { src = ./.; };
      flake = if (src == ./.) then
        self
      else
        (mkFlake {
          inherit src;
          inherit (self) flake-compat;
        });
      nixpkgs = flake.inputs.nixpkgs or self.inputs.nixpkgs;
      inherit (nixpkgs) lib legacyPackages;
      flakeAttrs = lib.filterAttrs (n: isAttrsOnly) flake;
      swap = system: builtins.mapAttrs (n: builtins.getAttr system) flakeAttrs;
      assign = system:
        builtins.mapAttrs (n: v: v // { currentSystem = v.${system}; })
        (lib.filterAttrs (n: builtins.hasAttr system) flakeAttrs);
      assignPkgs = current: attrs:
        (genAttrs [ "legacyPackages" "pkgs" ] (pkgs:
          if current then
            legacyPackages.${builtins.currentSystem}
          else
            (legacyPackages // {
              currentSystem = legacyPackages.${builtins.currentSystem};
            }))) // attrs;
    in {
      inherit lib;
    } // flake // {
      currentSystem = assignPkgs true
        (flake.${builtins.currentSystem} or (swap builtins.currentSystem));
    } // (assignPkgs false (assign builtins.currentSystem));
in (siluam ./.) // { __functor = self: siluam; }
