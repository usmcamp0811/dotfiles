{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.deploy-user;
in
{
  options.campground.deploy-user = with types; {
    enable = mkEnableOption "Enable the deploy user";
    name = mkOpt str "deploy" "The name to use for the user account.";
    authorizedKeys = mkOpt (listOf str) config.campground.services.openssh.authorizedKeys "The public keys to apply.";
    uid = mkOpt int 1001 "UID of the user";
    extraGroups = mkOpt (listOf str) [ ] "Groups for the user to be assigned.";
    extraOptions = mkOpt attrs { }
      "Extra options passed to <option>users.users.<name></option>.";
    GroupsIds = mkOption {
      type = types.attrsOf types.int;
      default = {
        users = 10000;
        k8s = 999;
        paperless = 317;
      };
      example = { wheel = 10; audio = 29; };
      description = "Groups and their corresponding IDs.";
    };
  };

  config = {
    users.users."${cfg.name}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; 
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    security.sudo.configFile = ''
      ${cfg.name} ALL=(ALL:ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
    '';
  };
}


