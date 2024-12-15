{ lib, ... }:
with lib; rec {
  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkOpt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt = type: default: description:
    mkOption { inherit type default description; };

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

  extractVaultPathAndFields = template:
    let
      # Simplified and compatible regular expressions
      vaultPathRegex = ''.*with secret "([^"]+)".*'';
      fieldRegex = ".*[{]{2}[ ]*\\.Data\\.data\\.([^ }]+)[ ]*[}]{2}.*";
      # Extract the Vault path (first match)
      extractVaultPath = builtins.match vaultPathRegex template;
      vaultPath =
        if extractVaultPath == null then null else extractVaultPath."1";

      # Recursive helper to extract all matches for fields
      extractAllMatches = regex: text:
        let
          loop = text: acc:
            let match = builtins.match regex text;
            in if match == null then
              acc
            else
              let
                remainingText =
                  builtins.substring (builtins.stringLength match."0")
                    (builtins.stringLength text - builtins.stringLength match."0")
                    text;
              in
              loop remainingText
                (acc ++ [ match."2" ]); # Match group 2 for the field name
        in
        loop text [ ];

      # Extract all fields
      fields = extractAllMatches fieldRegex template;
    in
    {
      path = vaultPath;
      fields = fields;
    };

  findVaultPathsAndFields = depth: systemConfig:
    if depth <= 0 then
      [ ]
    else
      let
        # The `vault-agent` configuration path
        vaultAgentConfig = systemConfig.services."vault-agent";

        # Collect paths and templates for files
        processFileTemplates = service:
          if builtins.hasAttr "secrets" service
            && builtins.hasAttr "file" service.secrets
            && builtins.hasAttr "files" service.secrets.file then
            builtins.foldl'
              (acc: key:
                let fileConfig = service.secrets.file.files.${key};
                in if builtins.hasAttr "text" fileConfig then
                  let template = fileConfig.text;
                  in acc ++ [{
                    path = service.settings.vault."vault-path" or null;
                    fields = [ template ];
                  }]
                else
                  acc) [ ]
              (builtins.attrNames service.secrets.file.files)
          else
            [ ];

        # Collect paths and templates for environment variables
        processEnvironmentTemplates = service:
          if builtins.hasAttr "secrets" service
            && builtins.hasAttr "environment" service.secrets
            && builtins.hasAttr "templates" service.secrets.environment then
            builtins.foldl'
              (acc: key:
                let envConfig = service.secrets.environment.templates.${key};
                in if builtins.hasAttr "text" envConfig then
                  let template = envConfig.text;
                  in acc ++ [{
                    path = service.settings.vault."vault-path" or null;
                    fields = [ template ];
                  }]
                else
                  acc) [ ]
              (builtins.attrNames service.secrets.environment.templates)
          else
            [ ];

        # Process a single service for both files and environment templates
        processService = service:
          processFileTemplates service ++ processEnvironmentTemplates service;

        # Process all `vault-agent` services
        processVaultAgentServices = services:
          builtins.foldl'
            (acc: serviceName:
              let service = services.${serviceName};
              in acc ++ processService service) [ ]
            (builtins.attrNames services);

      in
      if builtins.hasAttr "enable" vaultAgentConfig
        && vaultAgentConfig.enable or false then
        processVaultAgentServices vaultAgentConfig.services
      else
        [ ];

  findVaultPaths = depth: cfg:
    if depth <= 0 then
      [ ]
    else
      let
        isAttrs = x: builtins.isAttrs x && !builtins.isFunction x;
        tryRecurse = x:
          let res = builtins.tryEval (findVaultPaths (depth - 1) x);
          in if res.success then res.value else [ ];
        getSecretPaths = attr:
          if builtins.hasAttr "user-secrets" attr
            && attr.user-secrets.enable then
            let
              baseVaultPath = attr.user-secrets.vault-path or "";
              userNames = builtins.attrNames attr.user-secrets.users or [ ];
            in
            builtins.map (username: "${baseVaultPath}/${username}") userNames
          else
            [ ];
      in
      if isAttrs cfg then
        builtins.foldl'
          (acc: key:
            let
              value = cfg.${key};
              res = builtins.tryEval value;
            in
            if res.success then
              if isAttrs res.value then
                acc ++ (tryRecurse res.value)
              else if key == "vault-path" && cfg.enable or false then
                acc ++ [ res.value ]
              else
                acc
            else
              acc)
          (getSecretPaths cfg)
          (builtins.attrNames cfg)
      else
        [ ];

  ## Function to make shell Aliases / Functions
  ## Main reason to use this over the `home.shellAliases` is that this can handle 
  ## both simple aliases and things that should be functions.. aka things that require 
  ## inputs 
  convertAlias = aliasAttrs:
    builtins.concatStringsSep "\n" (mapAttrsToList
      (name: value:
        let
          containsDollar = builtins.elem "$" (lib.splitString "" value);
          containsNewline = builtins.elem "\n" (lib.splitString "" value);
        in
        if containsDollar || containsNewline then ''
          function '${name}'() {
            ${value}
          }
        '' else
          let
            # Escape single quotes in the alias value
            escapedValue = builtins.replaceStrings [ "'" ] [ "'\\''" ] value;
          in
          "alias -- '${name}'='${escapedValue}'")
      aliasAttrs);

}
