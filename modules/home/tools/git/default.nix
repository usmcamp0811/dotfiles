{ lib, config, pkgs, ... }:
let
  inherit (lib) types mkEnableOption mkIf;
  inherit (lib.campground) mkOpt enabled;

  cfg = config.campground.tools.git;
  user = config.campground.user;
in
{
  options.campground.tools.git = {
    enable = mkEnableOption "Git";
    userName = mkOpt types.str user.fullName "The name to configure git with.";
    userEmail = mkOpt types.str user.email "The email to configure git with.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ lazygit ];

    campground.cli.aliases = {
      undopush = "${pkgs.git}/bin/git push -f origin HEAD^:master";
      gr =
        "[ ! -z `${pkgs.git}/bin/git rev-parse --show-cdup` ] && cd `${pkgs.git}/bin/git rev-parse --show-cdup || pwd`";
      master = "${pkgs.git}/bin/git checkout master";

    };
    programs.git = {
      enable = true;
      userName = cfg.userName;
      userEmail = cfg.userEmail;
      ignores = [ "result" ];
      lfs = enabled;
      extraConfig = {
        init = { defaultBranch = "main"; };
        pull = { rebase = true; };
        push = { autoSetupRemote = true; };
        core = { whitespace = "trailing-space,space-before-tab"; };
        safe = { directory = "${user.home}/work/config"; };
      };
    };
  };
}
