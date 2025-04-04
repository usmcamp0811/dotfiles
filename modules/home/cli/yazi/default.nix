{ options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.cli.yazi;
  plugins = import ./plugins.nix { inherit pkgs; };
  millerYaziSrc = pkgs.fetchFromGitHub {
    owner = "Reledia";
    repo = "miller.yazi";
    rev = "master";
    sha256 = "sha256-GXZZ/vI52rSw573hoMmspnuzFoBXDLcA0fqjF76CdnY=";
  };

  officeYaziSrc = pkgs.runCommand "office.yazi-with-init" { } ''
    mkdir -p $out
    cp -r ${pkgs.fetchFromGitHub {
      owner = "macydnah";
      repo = "office.yazi";
      rev = "master";
      sha256 = "sha256-rZas/oMNI6H5lXOixDQcL/dQC+J9VCFrOOIIjjLDUc4=";
    }}/* $out/
    ln -s $out/main.lua $out/init.lua
  '';
in
{
  options.campground.cli.yazi = { enable = mkEnableOption "Yazi"; };

  config = mkIf cfg.enable {
    # campground.cli.aliases = {
    #   y = ''
    #     function y() {
    #       echo "Opening yazi"
    #     	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    #     	${pkgs.yazi}/bin/yazi "$@" --cwd-file="$tmp"
    #     	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    #     		builtin cd -- "$cwd"
    #     	fi
    #     	rm -f -- "$tmp"
    #     }
    #   '';
    # };
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      shellWrapperName = "y";
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
          manager = { show_hidden = true; };
          opener.edit = [
            {
              run = ''nvim "$@"'';
              block = true;
            }
          ];
        };

        plugin = {
          prepend_preloaders = [
            {
              mime = "application/openxmlformats-officedocument.*";
              run = "office";
            }

            {
              mime = "application/oasis.opendocument.*";
              run = "office";
            }
            {
              mime = "application/ms-*";
              run = "office";
            }

            {
              mime = "application/msword";
              run = "office";
            }

            {
              name = "*.docx";
              run = "office";
            }
          ];

          prepend_previewers = [
            {
              mime = "application/openxmlformats-officedocument.*";
              run = "office";
            }
            {
              mime = "application/oasis.opendocument.*";
              run = "office";
            }
            {
              mime = "application/ms-*";
              run = "office";
            }
            {
              mime = "application/msword";
              run = "office";
            }
            {
              name = "*.docx";
              run = "office";
            }
          ];
        };
      };
      plugins = {
        bookmarks = plugins.yaziBookmarkSrc;
        office = plugins.office;
        miller-preview = millerYaziSrc;
      };
    };
  };
}
