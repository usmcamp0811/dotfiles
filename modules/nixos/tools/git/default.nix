{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.git;
  user = config.campground.user;
in {
  options.campground.tools.git = with types; {
    enable = mkBoolOpt false "Whether or not to install and configure git.";
    userName = mkOpt types.str user.fullName "The name to configure git with.";
    userEmail = mkOpt types.str user.email "The email to configure git with.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [git lazygit];

    campground.home.extraOptions = {
      programs.git = {
        enable = true;

        # new API: everything under `settings`
        settings = {
          user = {
            name = mkForce cfg.userName;
            email = mkForce cfg.userEmail;
          };

          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
          core.whitespace = "trailing-space,space-before-tab";
          safe.directory = "${config.users.users.${user.name}.home}/work/config";
        };

        lfs = enabled;
      };
    };
  };
}
