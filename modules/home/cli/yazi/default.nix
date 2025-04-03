{ options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.cli.yazi;
in
{
  options.campground.cli.yazi = { enable = mkEnableOption "Yazi"; };

  config = mkIf cfg.enable {
    # campground.cli.aliases = {
    #   yazi = ''
    #     ${pkgs.yazi}/bin/yazi --choosedir=$HOME/.yazidir; LASTDIR=`cat $HOME/.yazidir`; cd "$LASTDIR"
    #   '';
    #   lr = ''
    #     ${pkgs.yazi}/bin/yazi --choosedir=$HOME/.yazidir; LASTDIR=`cat $HOME/.yazidir`; cd "$LASTDIR"
    #   '';
    # };
    programs.yazi = {
      enable = true;
      # enableZshIntegration = true;
      settings = {
        keymap = {
          manager.prepend_keymap = [
            {
              run = "close";
              on = [ "<C-q>" ];
            }
            {
              run = "yank --cut";
              on = [ "d" ];
            }
            {
              run = "remove --force";
              on = [ "D" ];
            }
            {
              run = "remove --permanently";
              on = [ "X" ];
            }
            {
              run = "plugin bookmarks --args=save";
              on = [ "m" ];
              desc = "Save current position as a bookmark";
            }
            {
              run = "plugin bookmarks --args=jump";
              on = [ "'" ];
              desc = "Jump to a bookmark";
            }
            {
              run = "plugin bookmarks --args=delete";
              on = [ "b" "d" ];
              desc = "Delete a bookmark";
            }
            {
              run = "plugin bookmarks --args=delete_all";
              on = [ "b" "D" ];
              desc = "Delete all bookmarks";
            }
          ];
        };
        yazi = {
          manager = {
            show_hidden = true;
          };
          opener.edit = [
            {
              run = "nvim \"$@\"";
              block = true;
            }
          ];
        };
      };
      plugins = {
        bookmarks = yaziBookmarkSrc;
      };
    };
  };
};
}
