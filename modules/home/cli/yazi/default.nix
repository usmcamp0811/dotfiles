{
  options,
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli.yazi;
in {
  options.fmf.cli.yazi = {enable = mkEnableOption "Yazi";};

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      mediainfo
      rich-cli
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
        kanagawa = "${inputs.kanagawa-yazi}";
        material-ocean = "${inputs.material-ocean-yazi}";
        onedark = "${inputs.onedark-yazi}";
      };
      theme.flavor = {
        dark = "onedark";
      };
      plugins = {
        chmod = "${pkgs.yaziPlugins.chmod}";
        diff = "${pkgs.yaziPlugins.diff}";
        full-border = "${pkgs.yaziPlugins.full-border}";
        git = "${pkgs.yaziPlugins.git}";
        toggle-pane = "${pkgs.yaziPlugins.toggle-pane}";
        mount = "${pkgs.yaziPlugins.mount}";
        smart-enter = "${pkgs.yaziPlugins.smart-enter}";
        vcs-files = "${pkgs.yaziPlugins.vcs-files}";

        # office = "${inputs.office-yazi}";
        rich-preview = "${pkgs.yaziPlugins.rich-preview}";
        eza-preview = "${inputs.eza-preview-yazi}";
        mediainfo = "${pkgs.yaziPlugins.mediainfo}";
        # fg = "${inputs.fzf-yazi}";
        glow = "${pkgs.yaziPlugins.glow}";
        # hexyl = "${inputs.hexyl-yazi}";
        ouch = "${pkgs.yaziPlugins.ouch}";
        # yatline = "${pkgs.yaziPlugins.yatline}";
        # yatline-catppuccin = "${pkgs.yaziPlugins.yatline-catppuccin}";
        lazygit = "${pkgs.yaziPlugins.lazygit}";
        # githead = "${inputs.githead-yazi}";
        duckdb = "${pkgs.yaziPlugins.duckdb}";
        # bunny = "${inputs.bunny-yazi}";
      };
      keymap = {
        mgr = {
          show_hidden = true;
          ratio = [1 2 5];
          show_symlink = true;
          prepend_keymap = [
            # {
            #   on = ";";
            #   run = "plugin bunny";
            #   desc = "Start bunny.yazi";
            # }
            {
              on = ["l"];
              run = "plugin smart-enter";
              desc = "Enter the child directory, or open the file";
            }
            {
              on = ["E"];
              run = "plugin eza-preview";
              desc = "Toggle tree/list dir preview";
            }
            {
              on = ["-"];
              run = "plugin eza-preview '--inc-level'";
              desc = "Increment tree level";
            }
            {
              on = ["_"];
              run = "plugin eza-preview '--dec-level'";
              desc = "Decrement tree level";
            }
            {
              on = ["$"];
              run = "plugin eza-preview '--toggle-follow-symlinks'";
              desc = "Toggle tree follow symlinks";
            }
            {
              on = ["<C-d>"];
              run = "plugin diff";
              desc = "Diff the selected with the hovered file";
            }
            {
              on = ["t" "g"];
              run = "plugin lazygit";
              desc = "run lazygit";
            }
            {
              on = ["g" "c"];
              run = "plugin vcs-files";
              desc = "Show Git file changes";
            }
            {
              on = ["T"];
              run = "plugin toggle-pane max-preview";
              desc = "Hide or show preview";
            }
            {
              on = ["M"];
              run = "plugin mount";
            }
            {
              on = ["<C-e>"];
              run = "seek 5";
            }
            {
              on = ["<C-y>"];
              run = "seek -5";
            }
            # {
            #   on = ["f" "g"];
            #   run = "plugin fg";
            #   desc = "find file by content";
            # }
            # {
            #   on = ["f" "f"];
            #   run = "plugin fg 'fzf'";
            #   desc = "find file by filename";
            # }
            # {
            #   on = ["f" "G"];
            #   run = "plugin fg 'rg'";
            #   desc = "find file by content (ripgrep match)";
            # }
            {
              on = ["C"];
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
              # yazi renamed the `name` rule field to `url` (glob); `name`
              # is no longer accepted in [open]/[plugin] rules.
              url = "*.{svg,png,jpg,jpeg,gif}";
              use = "openImage";
            }
            {
              url = "*.pdf";
              use = "openPdf";
            }
          ];
        };
        plugin = {
          prepend_preloaders = [
            {
              mime = "{audio,video,image}/*";
              run = "mediainfo";
            }
            {
              mime = "application/subrip";
              run = "mediainfo";
            }
            # {
            #   mime = "application/openxmlformats-officedocument.*";
            #   run = "office";
            # }
            # {
            #   mime = "application/oasis.opendocument.*";
            #   run = "office";
            # }
            # {
            #   mime = "application/ms-*";
            #   run = "office";
            # }
            # {
            #   mime = "application/msword";
            #   run = "office";
            # }
            # {
            #   name = "*.docx";
            #   run = "office";
            # }
            {
              url = "*.tsv";
              run = "duckdb";
            }
            {
              url = "*.parquet";
              run = "duckdb";
            }
            {
              url = "*.db";
              run = "duckdb";
            }
            {
              url = "*.duckdb";
              run = "duckdb";
            }
          ];
          prepend_previewers = [
            {
              url = "*/";
              run = "eza-preview";
            }
            {
              mime = "{audio,video}/*";
              run = "mediainfo";
            }
            {
              url = "*.{jpg,png,webp}";
              run = "mediainfo";
            }
            {
              mime = "application/subrip";
              run = "mediainfo";
            }
            {
              url = "*.tsv";
              run = "duckdb";
            }
            {
              url = "*.parquet";
              run = "duckdb";
            }
            {
              url = "*.csv";
              run = "rich-preview";
            }
            {
              url = "*.md";
              run = "rich-preview";
            }
            {
              url = "*.rst";
              run = "rich-preview";
            }
            {
              url = "*.ipynb";
              run = "rich-preview";
            }
            {
              url = "*.json";
              run = "rich-preview";
            }
            # {
            #   mime = "application/openxmlformats-officedocument.*";
            #   run = "office";
            # }
            # {
            #   mime = "application/oasis.opendocument.*";
            #   run = "office";
            # }
            # {
            #   mime = "application/ms-*";
            #   run = "office";
            # }
            # {
            #   mime = "application/msword";
            #   run = "office";
            # }
            # {
            #   name = "*.docx";
            #   run = "office";
            # }
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
