{ lib, config, pkgs, ... }:
let
  inherit (lib) types mkEnableOption mkIf;
  inherit (lib.namespace-change-me) mkOpt enabled;

  cfg = config.namespace-change-me.tools.git;
  user = config.namespace-change-me.user;
in {
  options.namespace-change-me.tools.git = {
    enable = mkEnableOption "Git";
    userName = mkOpt types.str user.fullName "The name to configure git with.";
    userEmail = mkOpt types.str user.email "The email to configure git with.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ lazygit ];

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
