{ ... }: {
  imports = [ ./lualine.nix ./toggleterm.nix ];
  keymaps = [
    {
      mode = "n";
      key = "<leader>m";
      options.desc = "Open your Mind";
      action = ":MindOpenMain<CR>";
    }
    {
      mode = "n";
      key = "<leader>,";
      options.desc = "Alpha";
      action = "<cmd>Alpha<cr>";
    }
    {
      mode = "n";
      key = "<leader>b";
      options.desc = "Buffers";
      action = "<cmd>BufferLinePick<cr>";
    }
    {
      mode = "n";
      key = "<leader>q";
      options.desc = "Quit";
      action = "<cmd>q!<CR>";
    }
    {
      mode = "n";
      key = "<leader>cx";
      options.desc = "Switch Slime to X11";
      action = "<cmd>lua SlimeXSwitch()<CR>";
    }
    {
      mode = "n";
      key = "<leader>cr";
      options.desc = "Restart Jupyter";
      action = ":MoltenRestart!<CR>";
    }
    {
      mode = "n";
      key = "<leader>cs";
      options.desc = "Start Jupyter";
      action = ":MoltenInit<CR>";
    }
    {
      mode = "n";
      key = "<leader>cD";
      options.desc = "Stop Jupyter";
      action = ":MoltenDeinit<CR>";
    }
    {
      mode = "n";
      key = "<leader>cd";
      options.desc = "Delete Current Cell";
      action = ":MoltenDelete<CR>";
    }
    {
      mode = "n";
      key = "<leader>co";
      options.desc = "Show Output";
      action = ":MoltenShowOutput<CR>";
    }
    {
      mode = "n";
      key = "<leader>ci";
      options.desc = "Interrupt Jupyter";
      action = ":MoltenInterrupt<CR>";
    }
    {
      mode = "n";
      key = "<leader>c<CR>";
      options.desc = "Run Cell";
      action = ":MoltenReevaluateCell<CR>";
    }
    {
      mode = "n";
      key = "<leader>Cc";
      options.desc = "Open Calendar";
      action = "<cmd>Calendar<CR>";
    }
    {
      mode = "n";
      key = "<leader>Cw";
      options.desc = "Week View";
      action = "<cmd>Calendar -view=week<CR>";
    }
    {
      mode = "n";
      key = "<leader>Cd";
      options.desc = "Day View";
      action = "<cmd>Calendar -view=day<CR>";
    }
    {
      mode = "n";
      key = "<leader>Cs";
      options.desc = "Day View";
      action = "<cmd>Calendar -view=days<CR>";
    }
    {
      mode = "n";
      key = "<leader>Co";
      options.desc = "Clock";
      action = "<cmd>Calendar -view=clock<CR>";
    }
    {
      mode = "n";
      key = "<leader>Cf";
      options.desc = "Open Side Calendar";
      action = "<cmd>Calendar -view=year -split=vertical -width=25<CR>";
    }
    {
      mode = "n";
      key = "<leader>h";
      options.desc = "No Highlight";
      action = "<cmd>nohlsearch<CR>";
    }
    {
      mode = "n";
      key = "<leader>f";
      options.desc = "Find files";
      action =
        "<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>";
    }
    {
      mode = "n";
      key = "<leader>F";
      options.desc = "Find Text";
      action = "<cmd>Telescope live_grep theme=ivy<cr>";
    }
    {
      mode = "n";
      key = "<leader>r";
      options.desc = "Search Recent Files";
      action = ":Telescope oldfiles <CR>";
    }
    {
      mode = "n";
      key = "<leader>w";
      options.desc = "Search Neorg Wiki";
      action = "<cmd>cd ~/vimwiki/home | :Telescope live_grep theme=ivy<cr>";
    }
    {
      mode = "n";
      key = "m";
      options = { desc = "Open your Mind"; };
      action = ":MindOpenMain<CR>";
    }
    {
      mode = "n";
      key = ",";
      options = { desc = "Alpha"; };
      action = "<cmd>Alpha<cr>";
    }
    {
      mode = "n";
      key = "b";
      options = { desc = "Buffers"; };
      action = "<cmd>BufferLinePick<cr>";
    }
    {
      mode = "n";
      key = "q";
      options = { desc = "Quit"; };
      action = "<cmd>q!<CR>";
    }
    {
      mode = "n";
      key = "cx";
      options = { desc = "Switch Slime to X11"; };
      action = "<cmd>lua SlimeXSwitch()<CR>";
    }
    {
      mode = "n";
      key = "cr";
      options = { desc = "Restart Jupyter"; };
      action = ":MoltenRestart!<CR>";
    }
    {
      mode = "n";
      key = "cs";
      options = { desc = "Start Jupyter"; };
      action = ":MoltenInit<CR>";
    }
    {
      mode = "n";
      key = "cD";
      options = { desc = "Stop Jupyter"; };
      action = ":MoltenDeinit<CR>";
    }
    {
      mode = "n";
      key = "cd";
      options = { desc = "Delete Current Cell"; };
      action = ":MoltenDelete<CR>";
    }
    {
      mode = "n";
      key = "co";
      options = { desc = "Show Output"; };
      action = ":MoltenShowOutput<CR>";
    }
    {
      mode = "n";
      key = "ci";
      options = { desc = "Interrupt Jupyter"; };
      action = ":MoltenInterrupt<CR>";
    }
    {
      mode = "n";
      key = "c<CR>";
      options = { desc = "Run Cell"; };
      action = ":MoltenReevaluateCell<CR>";
    }
    {
      mode = "n";
      key = "Cc";
      options = { desc = "Open Calendar"; };
      action = "<cmd>Calendar<CR>";
    }
    {
      mode = "n";
      key = "Cw";
      options = { desc = "Week View"; };
      action = "<cmd>Calendar -view=week<CR>";
    }
    {
      mode = "n";
      key = "Cd";
      options = { desc = "Day View"; };
      action = "<cmd>Calendar -view=day<CR>";
    }
    {
      mode = "n";
      key = "Cs";
      options = { desc = "Day View"; };
      action = "<cmd>Calendar -view=days<CR>";
    }
    {
      mode = "n";
      key = "Co";
      options = { desc = "Clock"; };
      action = "<cmd>Calendar -view=clock<CR>";
    }
    {
      mode = "n";
      key = "Cf";
      options = { desc = "Open Side Calendar"; };
      action = "<cmd>Calendar -view=year -split=vertical -width=25<CR>";
    }
    # {
    #   mode = "n";
    #   key = "h";
    #   options = { desc = "No Highlight"; };
    #   action = "<cmd>nohlsearch<CR>";
    # }
    # {
    #   mode = "n";
    #   key = "f";
    #   options = { desc = "Find files"; };
    #   action =
    #     "<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>";
    # }
    {
      mode = "n";
      key = "F";
      options = { desc = "Find Text"; };
      action = "<cmd>Telescope live_grep theme=ivy<cr>";
    }
    # {
    #   mode = "n";
    #   key = "r";
    #   options = { desc = "Search Recent Files"; };
    #   action = ":Telescope oldfiles <CR>";
    # }
    # {
    #   mode = "n";
    #   key = "w";
    #   options = { desc = "Search Neorg Wiki"; };
    #   action = "<cmd>cd ~/vimwiki/home | :Telescope live_grep theme=ivy<cr>";
    # }
  ];
  plugins = {
    # UI Enhancements
    nvim-tree.enable = true;
    leap = {
      enable = true;
      addDefaultMappings = true;
      maxPhaseOneTargets = null; # or an integer value if needed
      highlightUnlabeledPhaseOneTargets = false;
      maxHighlightedTraversalTargets = 10;
      caseSensitive = false;
      equivalenceClasses = [ " 	\r\n" ];
      substituteChars = { };
      # safeLabels and labels can be defined if needed
      specialKeys = {
        nextTarget = "<enter>";
        prevTarget = "<tab>";
        nextGroup = "<space>";
        prevGroup = "<tab>";
        multiAccept = "<enter>";
        multiRevert = "<backspace>";
      };
    };
    which-key = {
      enable = true;

      plugins = {
        marks = true;

        registers = true;

        spelling = {
          enabled = true;
          suggestions = 20;
        };

        presets = {
          operators = true;
          motions = true;
          textObjects = true;
          windows = true;
          nav = true;
          z = true;
          g = true;
        };
      };
      triggers = "auto";
      operators = { " " = "Comments"; };
      triggersBlackList = {
        i = [ "j" "k" ];
        v = [ "j" "k" ];
      };
      icons = {
        breadcrumb = "»";
        separator = "➜";
        group = "+";
      };

      popupMappings = {
        scrollDown = "<c-d>";
        scrollUp = "<c-u>";
      };
      window = {
        border = "rounded";
        position = "bottom";
        margin = {
          top = 1;
          right = 0;
          bottom = 1;
          left = 0;
        };
        padding = {
          top = 2;
          right = 2;
          bottom = 2;
          left = 2;
        };
        winblend = 0;
      };

      layout = {
        height = {
          min = 4;
          max = 25;
        };
        width = {
          min = 20;
          max = 50;
        };
        spacing = 3;
        align = "left";
      };
    };
    vim-bbye.enable = true;
    bufferline.enable = true;
    # lsp-lines.enable = true;
    lspsaga.enable = true;
    trouble.enable = true;
    mark-radar.enable = true;
    nvim-colorizer.enable = true;
    indent-blankline.enable = true;
  };
}
