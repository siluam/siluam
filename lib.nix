rec {
  inherit (builtins) trace;
  traceVal = value: trace value value;
  traceValSeq = value: trace (builtins.deepSeq value value) value;

  optionalAttrs = cond: attrs: if cond then attrs else { };
  optionalString = cond: string: if cond then string else "";

  stringToCharacters = s:
    builtins.genList (p: builtins.substring p 1 s) (builtins.stringLength s);
  lowerChars = stringToCharacters "abcdefghijklmnopqrstuvwxyz";
  upperChars = stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  toLower = builtins.replaceStrings upperChars lowerChars;
  toUpper = builtins.replaceStrings lowerChars upperChars;

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/lists.nix#L856C1-L864C73
  /* Remove duplicate elements from the list. O(n^2) complexity.

     Type: unique :: [a] -> [a]

     Example:
       unique [ 3 2 3 4 ]
       => [ 3 2 4 ]
  */
  unique =
    builtins.foldl' (acc: e: if builtins.elem e acc then acc else acc ++ [ e ])
    [ ];

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/lists.nix#L866C1-L876C59
  /* Check if list contains only unique elements. O(n^2) complexity.

     Type: allUnique :: [a] -> bool

     Example:
       allUnique [ 3 2 3 4 ]
       => false
       allUnique [ 3 2 4 1 ]
       => true
  */
  allUnique = list: (builtins.length (unique list) == builtins.length list);

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/strings.nix#L259C1-L284C53
  /* Determine whether a string has given prefix.

     Type: hasPrefix :: string -> string -> bool

     Example:
       hasPrefix "foo" "foobar"
       => true
       hasPrefix "foo" "barfoo"
       => false
  */
  hasPrefix =
    # Prefix to check for
    pref:
    # Input string
    str:
    # Before 23.05, paths would be copied to the store before converting them
    # to strings and comparing. This was surprising and confusing.
    if (builtins.isPath pref) then
      abort ''
        lib.strings.hasPrefix: The first argument (${
          toString pref
        }) is a path value, but only strings are supported.
            There is almost certainly a bug in the calling code, since this function always returns `false` in such a case.
            This function also copies the path to the Nix store, which may not be what you want.
            This behavior is deprecated.
            You might want to use `lib.path.hasPrefix` instead, which correctly supports paths.''
    else
      (builtins.substring 0 (builtins.stringLength pref) str == pref);

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/attrsets.nix#L616C1-L633C66
  /* Like `mapAttrs`, but allows the name of each attribute to be
     changed in addition to the value.  The applied function should
     return both the new name and value as a `nameValuePair`.

     Example:
       mapAttrs' (name: value: nameValuePair ("foo_" + name) ("bar-" + value))
          { x = "a"; y = "b"; }
       => { foo_x = "bar-a"; foo_y = "bar-b"; }

     Type:
       mapAttrs' :: (String -> Any -> { name :: String; value :: Any; }) -> AttrSet -> AttrSet
  */
  mapAttrs' =
    # A function, given an attribute's name and value, returns a new `nameValuePair`.
    f:
    # Attribute set to map over.
    set:
    builtins.listToAttrs
    (map (attr: f attr set.${attr}) (builtins.attrNames set));

  mapAttrNames = f:
    mapAttrs' (name: value: {
      name = f name value;
      inherit value;
    });

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/attrsets.nix#L636C1-L653C56
  /* Call a function for each attribute in the given set and return
     the result in a list.

     Example:
       mapAttrsToList (name: value: name + value)
          { x = "a"; y = "b"; }
       => [ "xa" "yb" ]

     Type:
       mapAttrsToList :: (String -> a -> b) -> AttrSet -> [b]
  */
  mapAttrsToList =
    # A function, given an attribute's name and value, returns a new value.
    f:
    # Attribute set to map over.
    attrs:
    map (name: f name attrs.${name}) (builtins.attrNames attrs);

  # Taken From: https://github.com/NixOS/nixpkgs/blob/master/lib/attrsets.nix#L765C1-L780C47
  /* Check whether the argument is a derivation. Any set with
     `{ type = "derivation"; }` counts as a derivation.

     Example:
       nixpkgs = import <nixpkgs> {}
       isDerivation nixpkgs.ruby
       => true
       isDerivation "foobar"
       => false

     Type:
       isDerivation :: Any -> Bool
  */
  isDerivation =
    # Value to check.
    value:
    value.type or null == "derivation";

  isAttrsOnly = value: (builtins.isAttrs value) && (!(isDerivation value));

  processInputs = inputs:
    builtins.mapAttrs (n: sourceInfo: rec {
      inherit sourceInfo;
      inherit (sourceInfo) outPath;
      _type = toLower (sourceInfo.repository.type or sourceInfo.type);
      inputs = { };
      outputs = { };
      lastModified = 0;
      lastModifiedDate = "";
      rev = sourceInfo.revision or sourceInfo.rev;
      shortRev = builtins.substring 0 7 rev;
    }) inputs;

  mkOutPath = args@{ src, owner ? "", repo ? "", rev ? "master", ... }:
    let
      name = args.name or repo;
      flakeLock = let path = src + "/flake.lock";
      in optionalAttrs (builtins.pathExists path)
      (builtins.fromJSON (builtins.readFile path));
      nivLock = let path = src + "/nix/sources.nix";
      in optionalAttrs (builtins.pathExists path) (import path);
      npinsLock = let path = src + "/npins";
      in optionalAttrs (builtins.pathExists path) (import path);
      lock = flakeLock.nodes.${name}.locked or { inherit rev; };
    in if (name != "") then
      (nivLock.${name} or npinsLock.${name} or {
        outPath = if ((owner != "") && (repo != "")) then
          (fetchTarball {
            url =
              lock.url or "https://github.com/${owner}/${repo}/archive/${lock.rev}.tar.gz";
            ${if (lock ? narHash) then "sha256" else null} = lock.narHash;
          })
        else
          src;
      }).outPath
    else
      src;

  mkFlake = args@{ src, shell ? false, ... }:
    let
      srcString = toString src;
      flake = if (builtins ? getFlake) then
        (builtins.getFlake srcString)
      else
        (let
          flake-compat = args.flake-compat or (import (mkOutPath {
            inherit src;
            owner = "edolstra";
            repo = "flake-compat";
          }) src);
          outPath = let path = mkOutPath args;
          in if (srcString == (toString path)) then
            src
          else
            (builtins.unsafeDiscardStringContext path);
        in flake-compat { src = outPath; }).${
          if shell then "shellNix" else "defaultNix"
        };
    in flake // {
      inputs = mkInputs {
        inherit src;
        inherit (flake) inputs;
      };
    };

  # TODO: Remove the tryEval from here
  # recursiveUpdateAll' = delim: a: b:
  #   let a-names = attrNames a;
  #   in (mapAttrs (n: v:
  #     let e = tryEval v;
  #     in if (e.success && (isAttrsOnly v)) then
  #       (if (any (attr:
  #         let g = tryEval attr;
  #         in g.success
  #         && ((isAttrsOnly attr) || (isList attr) || (isString attr)))
  #         (attrValues v)) then
  #         (recursiveUpdateAll' delim v (b.${n} or { }))
  #       else
  #         (v // (b.${n} or { })))
  #     else if (isList v) then
  #       (v ++ (b.${n} or [ ]))
  #     else if ((delim != null) && (isString v)) then
  #       (if (hasAttr n b) then (v + delim + b.${n}) else v)
  #     else
  #       (b.${n} or v)) a) // (removeAttrs b a-names);
  recursiveUpdateAll' = delim: a: b:
    let a-names = builtins.attrNames a;
    in (builtins.mapAttrs (n: v:

      # TODO: Is this `tryEval' necessary?
      let e = builtins.tryEval v;
      in if (e.success && (builtins.any (x: x) [ (isAttrsOnly v) ])) then

      # TODO: Need this to merge mkShells
      # in if (e.success && ((isAttrsOnly v) || (v ? shellHook))) then

      # (if (any (attr: (isAttrs attr) || (isList attr) || (isString attr))
      #   (attrValues v)) then
      #   (recursiveUpdateAll' delim v (b.${n} or { }))
      # else
      #   (v // (b.${n} or { })))
        (recursiveUpdateAll' delim v (b.${n} or { }))
      else if (e.success && (isDerivation v)
        && (b.${n}.__append__ or false)) then
        (recursiveUpdateAll' delim v (removeAttrs b.${n} [ "__append__" ]))
      else if (builtins.isList v) then
        (v ++ (b.${n} or [ ]))
      else if ((delim != null) && (builtins.isString v)) then
        (if (builtins.hasAttr n b) then (v + delim + b.${n}) else v)
      else
        (b.${n} or (if (n == "overridePythonAttrs") then "" else v))) a)
    // (removeAttrs b a-names);
  recursiveUpdateAll = recursiveUpdateAll' null;

  mkInputs =
    args@{ src, inputs ? { }, niv ? true, npins ? true, overrides ? { }, ... }:
    let
      mkFlakes = default: manager:
        let
          managerIsString = builtins.isString manager;
          bool = managerIsString || ((builtins.isBool manager) && manager);
          path =
            optionalString bool (if managerIsString then manager else default);
          rootPath = src + "/${path}";
        in optionalAttrs (bool && (builtins.pathExists rootPath))
        (builtins.mapAttrs (name: v:
          let
            outPath = if (hasPrefix "/" v.outPath) then
              (builtins.unsafeDiscardStringContext v.outPath)
            else
              (src + "/${v.outPath}");
            flakePath = outPath + "/flake.nix";
          in if (builtins.pathExists flakePath) then
            (mkFlake {
              inherit name;
              src = outPath;
              owner = v.repository.owner or v.owner;
              repo = v.repository.repo or v.repo;
              inherit (v) rev;
            })
          else
            (processInputs v)) (import rootPath));
    in builtins.foldl' (a: b: a // b) inputs (mapAttrsToList mkFlakes {
      "nix/sources.nix" = niv;
      npins = npins;
    });
}
