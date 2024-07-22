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

  keymaps = [
    {
      mode = "n";
      key = "<leader>sb";
      options.desc = "Checkout branch";
      action = "<cmd>Telescope git_branches<cr>";
    }
    {
      mode = "n";
      key = "<leader>sc";
      options.desc = "Colorscheme";
      action = "<cmd>Telescope colorscheme<cr>";
    }
    {
      mode = "n";
      key = "<leader>sh";
      options.desc = "Find Help";
      action = "<cmd>Telescope help_tags<cr>";
    }
    {
      mode = "n";
      key = "<leader>sM";
      options.desc = "Man Pages";
      action = "<cmd>Telescope man_pages<cr>";
    }
    {
      mode = "n";
      key = "<leader>sF";
      options.desc = "Find Text in Project";
      action = "<cmd>Telescope live_grep<cr>";
    }
    {
      mode = "n";
      key = "<leader>sr";
      options.desc = "Open Recent File";
      action = "<cmd>Telescope oldfiles<cr>";
    }
    {
      mode = "n";
      key = "<leader>sR";
      options.desc = "Registers";
      action = "<cmd>Telescope registers<cr>";
    }
    {
      mode = "n";
      key = "<leader>sk";
      options.desc = "Keymaps";
      action = "<cmd>Telescope keymaps<cr>";
    }
    {
      mode = "n";
      key = "<leader>sC";
      options.desc = "Commands";
      action = "<cmd>Telescope commands<cr>";
    }
  ];
}
