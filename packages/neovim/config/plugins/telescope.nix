{ pkgs, ... }: {
  plugins = {
    # Telescope
    telescope = {
      enable = true;
      extensions = {
        fzf-native.enable = true; # so fzf gets in teh path
        # media-files.enable = true;
        # undo.enable = true;
      };
    };
  };

  extraPlugins = with pkgs.vimPlugins; [
    telescope-symbols-nvim
    telescope-media-files-nvim
    telescope-live-grep-args-nvim
  ];

  extraConfigLua = ''
    which_key.register({
      s = {
        name = "Search",
        b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
        c = { "<cmd>Telescope colorscheme<cr>", "Colorscheme" },
        h = { "<cmd>Telescope help_tags<cr>", "Find Help" },
        M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
        F = { "<cmd>Telescope live_grep<cr>", "Find Text in Project" },
        r = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
        R = { "<cmd>Telescope registers<cr>", "Registers" },
        k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
        C = { "<cmd>Telescope commands<cr>", "Commands" },
      },
    },
      { prefix = "<leader>" }
    )
  '';
}
