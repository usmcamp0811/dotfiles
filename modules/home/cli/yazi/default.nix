{ options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.cli.yazi;
  plugin = import ./plugins.nix { inherit pkgs; };
in
{
  options.campground.cli.yazi = { enable = mkEnableOption "Yazi"; };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      mediainfo
      ouch
      glow
      hexyl
      antiprism
      fzf
      eza
      duckdb
    ];
    programs.yazi = {
      enable = true;
      initLua = ./init.lua;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      shellWrapperName = "lr";
      flavors = {
        kanagawa = "${plugin.kanagawa}";
        material-ocean = "${plugin.material-ocean}";
        onedark = "${plugin.onedark}";
      };
      theme.flavor = {
        dark = "onedark";
      };
      plugins = {
        chmod = "${plugin.official-plugins}/chmod.yazi";
        diff = "${plugin.official-plugins}/diff.yazi";
        full-border = "${plugin.official-plugins}/full-border.yazi";
        git = "${plugin.official-plugins}/git.yazi";
        toggle-pane = "${plugin.official-plugins}/toggle-pane.yazi";
        mount = "${plugin.official-plugins}/mount.yazi";
        smart-enter = "${plugin.official-plugins}/smart-enter.yazi";
        vcs-files = "${plugin.official-plugins}/vcs-files.yazi";
        office = "${plugin.office}";
        rich-preview = "${plugin.rich-preview}";
        eza-preview = "${plugin.eza-preview}";
        mediainfo = "${plugin.mediainfo}";
        fg = "${plugin.fzf}";
        glow = "${plugin.glow}";
        hexyl = "${plugin.hexyl}";
        ouch = "${plugin.ouch}";
        yaziline = "${plugin.yaziline}";
        lazygit = "${plugin.lazygit}";
        githead = "${plugin.githead}";
        duckdb = "${plugin.duckdb}";
      };
      keymap = {
        manager = {
          ratio = [ 1 2 5 ];
          show_symlink = true;
          prepend_keymap = [
            {
              on = [ "l" ];
              run = "plugin smart-enter";
              desc = "Enter the child directory, or open the file";
            }
            {
              on = [ "E" ];
              run = "plugin eza-preview";
              desc = "Toggle tree/list dir preview";
            }

            {
              on = [ "-" ];
              run = "plugin eza-preview '--inc-level'";
              desc = "Increment tree level";
            }

            {
              on = [ "_" ];
              run = "plugin eza-preview '--dec-level'";
              desc = "Decrement tree level";
            }

            {
              on = [ "$" ];
              run = "plugin eza-preview '--toggle-follow-symlinks'";
              desc = "Toggle tree follow symlinks";
            }

            {
              on = [ "<C-d>" ];
              run = "plugin diff";
              desc = "Diff the selected with the hovered file";
            }

            {
              on = [ "t" "g" ];
              run = "plugin lazygit";
              desc = "run lazygit";
            }
            {
              on = [ "g" "c" ];
              run = "plugin vcs-files";
              desc = "Show Git file changes";
            }

            {
              on = [ "T" ];
              run = "plugin toggle-pane max-preview";
              desc = "Hide or show preview";
            }

            {
              on = [ "M" ];
              run = "plugin mount";
            }

            {
              on = [ "<C-e>" ];
              run = "seek 5";
            }

            {
              on = [ "<C-y>" ];
              run = "seek -5";
            }

            {
              on = [ "f" "g" ];
              run = "plugin fg";
              desc = "find file by content";
            }

            {
              on = [ "f" "f" ];
              run = "plugin fg 'fzf'";
              desc = "find file by filename";
            }

            {
              on = [ "f" "G" ];
              run = "plugin fg 'rg'";
              desc = "find file by content (ripgrep match)";
            }

            {
              on = [ "C" ];
              run = "plugin ouch zip";
              desc = "Compress with ouch";
            }
          ];
        };
      };
      settings = {
        preview = {
          image_filter = "catmull-rom";
          image_quality = 80;
        };
        opener = {
          openImage = [
            {
              run = ''${pkgs.feh}/bin/feh "$@" '';
              block = true;
              for = "unix";
            }
          ];
          openPdf = [
            {
              run = ''${pkgs.zathura}/bin/zathura "$@" '';
              block = true;
              for = "unix";
            }
          ];
          extract = [
            {
              run = ''${pkgs.ouch}/bin/ouch d -y "$@" '';
              desc = "Extract here with ouch";
              for = "unix";
            }
          ];
        };

        open = {
          prepend_rules = [
            {
              name = "*.{svg,png,jpg,jpeg,gif}";
              use = "openImage";
            }
            {
              name = "*.pdf";
              use = "openPdf";
            }
          ];
        };

        plugin = {
          prepend_fetchers = [
            {
              id = "git";
              name = "*";
              run = "git";
            }

            {
              id = "git";
              name = "*/";
              run = "git";
            }
          ];
          prepend_preloaders = [
            {
              mime = "{audio,video,image}/*";
              run = "mediainfo";
            }

            {
              mime = "application/subrip";
              run = "mediainfo";
            }

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
            # {
            #   name = "*.csv";
            #   run = "duckdb";
            # }
            {
              name = "*.tsv";
              run = "duckdb";
            }
            # {
            #   name = "*.json";
            #   run = "duckdb";
            # }
            {
              name = "*.parquet";
              run = "duckdb";
            }
            {
              name = "*.db";
              run = "duckdb";
            }
            {
              name = "*.duckdb";
              run = "duckdb";
            }
          ];
          prepend_previewers = [
            {
              name = "*/";
              run = "eza-preview";
            }

            {
              mime = "{audio,video}/*";
              run = "mediainfo";
            }

            {
              name = "*.{jpg,png,webp}";
              run = "mediainfo";
            }

            {
              mime = "application/subrip";
              run = "mediainfo";
            }
            # {
            #   name = "*.csv";
            #   run = "duckdb";
            # }
            {
              name = "*.tsv";
              run = "duckdb";
            }
            # {
            #   name = "*.json";
            #   run = "duckdb";
            # }
            {
              name = "*.parquet";
              run = "duckdb";
            }

            {
              name = "*.csv";
              run = "rich-preview";
            }

            {
              name = "*.md";
              run = "rich-preview";
            }

            {
              name = "*.rst";
              run = "rich-preview";
            }

            {
              name = "*.ipynb";
              run = "rich-preview";
            }

            {
              name = "*.json";
              run = "rich-preview";
            }

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

            {
              mime = "application/*zip";
              run = "ouch";
            }

            {
              mime = "application/x-tar";
              run = "ouch";
            }

            {
              mime = "application/x-tar.gz";
              run = "ouch";
            }

            {
              mime = "application/x-bzip2";
              run = "ouch";
            }

            {
              mime = "application/x-7z-compressed";
              run = "ouch";
            }

            {
              mime = "application/x-rar";
              run = "ouch";
            }

            {
              mime = "application/x-xz";
              run = "ouch";
            }
          ];
        };
      };
    };
  };
}
