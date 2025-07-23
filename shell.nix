let siluam = toString ./.;
in with (import siluam).legacyPackages.currentSystem;
mkShell {
  buildInputs = [ git just nixfmt ];
  shellHook = ''
    nixfmt ${siluam}
    git -C ${siluam} add .
    nix flake update ${siluam}
    exec nix repl -L --show-trace --expr "{ siluam = import ${siluam}; }"
  '';
}
