# siluam

```nix
let
  siluam = ssrc:
    import (let
      lock = if (builtins.pathExists ./flake.lock) then
        (builtins.fromJSON (builtins.readFile ./flake.lock))
      else
        { };
      locked = lock.nodes.siluam.locked or { rev = "main"; };
      url = locked.url or "https://github.com/siluam/siluam/archive/${
          locked.rev or "main"
        }.tar.gz";
    in if ((ssrc != ./.) && (builtins.pathExists ssrc)) then
      ssrc
    else if (builtins ? getFlake) then
      (builtins.getFlake url)
    else
      (fetchTarball {
        inherit url;
        ${if (locked ? narHash) then "sha256" else null} = locked.narHash;
      }));
in { __functor = self: ssrc: siluam ssrc ./.; } // (siluam ./. ./.)
```