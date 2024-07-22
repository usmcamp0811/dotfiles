{ ... }: {

  keymaps = [
    {
      mode = "n";
      key = "<leader>tj";
      options.desc = "Julia Terminal";
      action = "<cmd>lua _JULIA_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>z";
      options.desc = "Julia Terminal";
      action = "<cmd>lua _JULIA_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tc";
      options.desc = "Clojure Terminal";
      action = "<cmd>lua _CLOJURE_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tp";
      options.desc = "Python Terminal";
      action = "<cmd>lua _PYTHON_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tn";
      options.desc = "Node Terminal";
      action = "<cmd>lua _NODE_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tl";
      options.desc = "Lua Terminal";
      action = "<cmd>lua _LUA_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tg";
      options.desc = "Lazygit Terminal";
      action = "<cmd>lua _LAZYGIT_TOGGLE()<CR>";
    }
    {
      mode = "n";
      key = "<leader>tu";
      options.desc = "NCDU Terminal";
      action = "<cmd>lua _NCDU_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tt";
      options.desc = "HTOP Terminal";
      action = "<cmd>lua _HTOP_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tk";
      options.desc = "K9s Terminal";
      action = "<cmd>lua _K9S_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tf";
      options.desc = "Float Terminal";
      action = "<cmd>ToggleTerm direction=float<cr>";
    }
    {
      mode = "n";
      key = "<leader>th";
      options.desc = "HShell Terminal";
      action = "<cmd>lua _HSHELL_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tv";
      options.desc = "VShell Terminal";
      action = "<cmd>lua _VSHELL_TOGGLE()<cr>";
    }
    {
      mode = "n";
      key = "<leader>tr";
      options.desc = "Rnvimr Toggle";
      action = ":RnvimrToggle<CR>";
    }
  ];
  plugins = {
    toggleterm.enable = true;
    which-key = { enable = true; };
  };

  extraConfigLua = ''
    local status_ok, toggleterm = pcall(require, "toggleterm")
    if not status_ok then
    	return
    end

    toggleterm.setup({
    	size = function(term)
    		if term.direction == "horizontal" then
    			return 15
    		elseif term.direction == "vertical" then
    			return vim.o.columns * 0.4
    		end
    	end,
    	open_mapping = [[<F1>]],
    	hide_numbers = true,
    	shade_filetypes = {},
    	shade_terminals = false,
    	shading_factor = 2,
    	start_in_insert = true,
    	insert_mappings = true,
    	persist_size = true,
    	direction = "float",
    	close_on_exit = true,
    	shell = vim.o.shell,
    	float_opts = {
    		border = "curved",
    		winblend = 0,
    		highlights = {
    			border = "Normal",
    			background = "Normal",
    		},
    	},
    })

    function _G.set_terminal_keymaps()
    	local opts = { noremap = true }
    	vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
    	vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
    	vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
    	vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
    	vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
    end

    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    local Terminal = require("toggleterm.terminal").Terminal
    local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

    function _LAZYGIT_TOGGLE()
    	lazygit:toggle()
    end

    local node = Terminal:new({
    	cmd = "node",
    	dir = "git_dir",
    	direction = "vertical",
    	on_open = function()
    		vim.g.node_job_id = vim.b.terminal_job_id
    	end,
    })

    function _NODE_TOGGLE()
    	node:toggle()
    	vim.cmd("wincmd h")
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.node_job_id,
    	}
    	vim.cmd("wincmd l")
    end

    local ncdu = Terminal:new({ cmd = "ncdu", hidden = true })

    function _NCDU_TOGGLE()
    	ncdu:toggle()
    end

    local bpytop = Terminal:new({ cmd = "bpytop", hidden = true })

    function _BPYTOP_TOGGLE()
    	bpytop:toggle()
    end

    local k9s = Terminal:new({ cmd = "k9s", hidden = true })

    function _K9S_TOGGLE()
    	k9s:toggle()
    end

    local htop = Terminal:new({ cmd = "htop", hidden = true })

    function _HTOP_TOGGLE()
    	htop:toggle()
    end

    local vshell = Terminal:new({
    	cmd = "zsh",
    	dir = "git_dir",
    	direction = "vertical",
    	on_open = function()
    		vim.g.vshell_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.vshell_job_id = nil
    	end,
    })

    function _VSHELL_TOGGLE()
    	vshell:toggle()
    	vim.cmd("wincmd h")
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.vshell_job_id,
    	}
    	vim.cmd("wincmd l")
    end

    local hshell = Terminal:new({
    	cmd = "zsh",
    	dir = "git_dir",
    	direction = "horizontal",
    	on_open = function()
    		vim.g.hshell_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.hshell_job_id = nil
    	end,
    })

    function _HSHELL_TOGGLE()
    	hshell:toggle()
    	vim.cmd("wincmd k")
    	vim.g.slime_target = "neovim"
    	vim.g.slime_dont_ask_default = 1
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.hshell_job_id,
    	}
    	vim.cmd("wincmd j")
    end

    local clojure = Terminal:new({
    	cmd = "clj -M:repl/conjure || clojure -M:repl/remote --port 8794 --host localhost",
    	dir = "git_dir",
      name = "clojure",
      count = 38,
    	direction = "vertical",
    	on_open = function()
    		vim.g.clojure_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.clojure_job_id = nil
    	end,
    })

    function _CLOJURE_TOGGLE()
    	clojure:toggle()
    	vim.cmd("wincmd h")
    	vim.g.slime_target = "neovim"
    	vim.g.slime_dont_ask_default = 1
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.clojure_job_id,
    	}
    	vim.cmd("wincmd l")
    end

    local python = Terminal:new({
    	cmd = "ipython --matplotlib",
      name = "pyton",
      count = 314,
    	dir = "git_dir",
    	direction = "vertical",
    	on_open = function()
    		vim.g.python_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.python_job_id = nil
    	end,
    	shade_terminals = true,
    })

    function _PYTHON_TOGGLE()
    	python:toggle()
    	vim.cmd("wincmd h")
    	vim.g.slime_target = "neovim"
    	vim.g.slime_dont_ask_default = 1
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.python_job_id,
    	}
    	vim.cmd("wincmd l")
    end

    local julia = Terminal:new({
    	cmd = "julia",
      name = "julia",
      count = 42,
    	dir = "git_dir",
    	direction = "vertical",
    	on_open = function()
    		vim.g.julia_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.julia_job_id = nil
    	end,

    })

    function _JULIA_TOGGLE()
    	julia:toggle()
    	vim.cmd("wincmd h")
    	vim.g.slime_target = "neovim"
    	vim.g.slime_dont_ask_default = 1
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.julia_job_id,
    	}
      vim.cmd(":let g:julia_bufnr=bufnr('%')")
    	vim.cmd("wincmd l")
    end

    local lua = Terminal:new({
    	cmd = "lua",
    	dir = "git_dir",
    	direction = "vertical",
    	on_open = function()
    		vim.g.lua_job_id = vim.b.terminal_job_id
    	end,
      on_close = function()
    		vim.g.lua_job_id = nil
    	end,
    })

    function _LUA_TOGGLE()
    	lua:toggle()
    	vim.cmd("wincmd h")
    	vim.g.slime_target = "neovim"
    	vim.g.slime_dont_ask_default = 1
    	vim.b.slime_config = {}
    	vim.b.slime_config = {
    		jobid = vim.g.lua_job_id,
    	}
    	vim.cmd("wincmd l")
    end

    local status_ok, which_key = pcall(require, "which-key")
    if not status_ok then
    	return
    end

  '';
}
