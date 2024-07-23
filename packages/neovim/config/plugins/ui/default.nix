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
    {
      mode = "n";
      key = "h";
      options = { desc = "No Highlight"; };
      action = "<cmd>nohlsearch<CR>";
    }
    {
      mode = "n";
      key = "f";
      options = { desc = "Find files"; };
      action =
        "<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>";
    }
    {
      mode = "n";
      key = "F";
      options = { desc = "Find Text"; };
      action = "<cmd>Telescope live_grep theme=ivy<cr>";
    }
    {
      mode = "n";
      key = "r";
      options = { desc = "Search Recent Files"; };
      action = ":Telescope oldfiles <CR>";
    }
    {
      mode = "n";
      key = "w";
      options = { desc = "Search Neorg Wiki"; };
      action = "<cmd>cd ~/vimwiki/home | :Telescope live_grep theme=ivy<cr>";
    }
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

      # registrations = {
      #   "<leader>" = {
      #     m = { ":MindOpenMain<CR>", "Open your Mind" };
      #     [","] = { "<cmd>Alpha<cr>", "Alpha" };
      #     b = { "<cmd>BufferLinePick<cr>", "Buffers" };
      #     q = { "<cmd>q!<CR>", "Quit" };
      #     c = {
      #       name = "Code";
      #       x = { "<cmd>lua SlimeXSwitch()<CR>", "Switch Slime to X11" };
      #       r = { ":MoltenRestart!<CR>", "Restart Jupyter" };
      #       s = { ":MoltenInit<CR>", "Start Jupyter" };
      #       D = { ":MoltenDeinit<CR>", "Stop Jupyter" };
      #       d = { ":MoltenDelete<CR>", "Delete Current Cell" };
      #       o = { ":MoltenShowOutput<CR>", "Show Output" };
      #       i = { ":MoltenInterrupt<CR>", "Interrupt Jupyter" };
      #       ["<CR>"] = { ":MoltenReevaluateCell<CR>", "Run Cell" };
      #     };
      #     C = {
      #       name = "Calendar";
      #       c = { "<cmd>Calendar<CR>", "Open Calendar" };
      #       w = { "<cmd>Calendar -view=week<CR>", "Week View" };
      #       d = { "<cmd>Calendar -view=day<CR>", "Day View" };
      #       s = { "<cmd>Calendar -view=days<CR>", "Day View" };
      #       o = { "<cmd>Calendar -view=clock<CR>", "Clock" };
      #       f = { "<cmd>Calendar -view=year -split=vertical -width=25<CR>", "Open Side Calendar" };
      #     };
      #     h = { "<cmd>nohlsearch<CR>", "No Highlight" };
      #     f = { "<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>", "Find files" };
      #     F = { "<cmd>Telescope live_grep theme=ivy<cr>", "Find Text" };
      #     r = { ":Telescope oldfiles <CR>", "Search Recent Files" };
      #     w = { "<cmd>cd ~/vimwiki/home | :Telescope live_grep theme=ivy<cr>", "Search Neorg Wiki" };
      #   };
      # };
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

  extraConfigLua = ''
    local status_ok, which_key = pcall(require, "which-key")
    if not status_ok then
    	return
    end

    vim.opt.timeoutlen = 300

    local setup = {
    	-- add operators that will trigger motion and text object completion
    	-- to enable all native operators, set the preset / operators plugin above
    	-- operators = { gc = "Comments" },
    	ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
    	hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
    	show_help = true, -- show help message on the command line when the popup is visible
    }

    local opts = {
    	mode = "n", -- NORMAL mode
    	prefix = "<leader>",
    	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
    	silent = true, -- use `silent` when creating keymaps
    	noremap = true, -- use `noremap` when creating keymaps
    	nowait = true, -- use `nowait` when creating keymaps
    }
    -- ["E"] = { "<cmd>NvimTreeToggle<cr>", "Explorer" },

    local diagnostics_active = true
    local toggle_diagnostics = function()
    	diagnostics_active = not diagnostics_active
    	if diagnostics_active then
    		vim.diagnostic.show()
    	else
    		vim.diagnostic.hide()
    	end
    end

    function norg_code_runner()
    	vim.cmd("s@cojVs@e")
    end

    which_key.setup(setup)
    which_key.register(mappings, opts)


  '';
}
