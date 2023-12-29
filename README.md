# siluam

```nix
import (let
  lock = if (builtins.pathExists ./flake.lock) then
    (builtins.fromJSON (builtins.readFile ./flake.lock))
  else
    { };
  locked = lock.nodes.siluam.locked or { rev = "main"; };
  url =
    locked.url or "https://github.com/siluam/siluam/archive/${locked.rev}.tar.gz";
in if (builtins ? getFlake) then
  (builtins.getFlake url)
else
  (fetchTarball {
    inherit url;
    ${if (locked ? narHash) then "sha256" else null} = locked.narHash;
  })) ./.
```