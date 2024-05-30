{lib, ...}:
with lib; rec {
  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkOpt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt = type: default: description:
    mkOption {inherit type default description;};

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkOpt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt' = type: default: mkOpt type default null;

  ## Create a boolean NixOS module option.
  ##
  ## ```nix
  ## lib.mkBoolOpt true "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt = mkOpt types.bool;

  ## Create a boolean NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkBoolOpt true
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt' = mkOpt' types.bool;

  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  findVaultPaths = depth: cfg:
    if depth <= 0
    then []
    else let
      isAttrs = x: builtins.isAttrs x && !builtins.isFunction x;
      tryRecurse = x: let
        res = builtins.tryEval (findVaultPaths (depth - 1) x);
      in
        if res.success
        then res.value
        else [];
      getSecretPaths = attr:
        if
          builtins.hasAttr "user-secrets" attr
          && attr.user-secrets.enable
        then let
          baseVaultPath = attr.user-secrets.vault-path or "";
          userNames = builtins.attrNames attr.user-secrets.users or [];
        in
          builtins.map (username: "${baseVaultPath}/${username}") userNames
        else [];
    in
      if isAttrs cfg
      then
        builtins.foldl' (acc: key: let
          value = cfg.${key};
          res = builtins.tryEval value;
        in
          if res.success
          then
            if isAttrs res.value
            then acc ++ (tryRecurse res.value)
            else if key == "vault-path" && cfg.enable or false
            then acc ++ [res.value]
            else acc
          else acc) (getSecretPaths cfg) (builtins.attrNames cfg)
      else [];
}
