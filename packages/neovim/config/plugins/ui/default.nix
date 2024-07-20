{ ... }: {
  imports = [ ./lualine.nix ./toggleterm.nix ];

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
    lsp-lines.enable = true;
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
    local mappings = {
    	-- ["<CR>"] = {":IPythonCellExecuteCell<cr>", "Execute # ``` Code Cell"},
    	-- ["\\"] = {":SlimeSendCurrentLine<cr>", "Execute Line of Code"},
    	m = { ":MindOpenMain<CR>", "Open your Mind" },
    	[","] = { "<cmd>Alpha<cr>", "Alpha" },
    	["b"] = {
    		"<cmd>BufferLinePick<cr>",
    		"Buffers",
    	},
    	["q"] = { "<cmd>q!<CR>", "Quit" },
    	-- ["c"] = { "<cmd>Calendar -view=year -split=vertical -width=25<CR>", "Open Side Calendar" },

    	c = {
    		name = "Code",
    		x = { "<cmd>lua SlimeXSwitch()<CR>", "Switch Slime to X11" },
        r = { ":MoltenRestart!<CR>", "Restart Jupyter"},
        s = { ":MoltenInit<CR>", "Start Jupyter"},
        D = { ":MoltenDeinit<CR>", "Stop Jupyter"},
        d = { ":MoltenDelete<CR>", "Delete Current Cell"},
        o = { ":MoltenShowOutput<CR>", "Show Output" },
        i = { ":MoltenInterrupt<CR>", "Interrupt Jupyter"},
        ["<CR>"] = { ":MoltenReevaluateCell<CR>", "Run Cell" }

    	},
    	["C"] = {
    		name = "Calendar",
    		c = { "<cmd>Calendar<CR>", "Open Calendar" },
    		w = { "<cmd>Calendar -view=week<CR>", "Week View" },
    		d = { "<cmd>Calendar -view=day<CR>", "Day View" },
    		s = { "<cmd>Calendar -view=days<CR>", "Day View" },
    		o = { "<cmd>Calendar -view=clock<CR>", "Clock" },
    		f = { "<cmd>Calendar -view=year -split=vertical -width=25<CR>", "Open Side Calendar" },
    	},
    	["h"] = { "<cmd>nohlsearch<CR>", "No Highlight" },
    	["f"] = {
    		"<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>",
    		"Find files",
    	},
    	["F"] = { "<cmd>Telescope live_grep theme=ivy<cr>", "Find Text" },
    	-- ["P"] = { "<cmd>lua require('telescope').extensions.projects.projects()<cr>", "Projects" },
    	["r"] = { ":Telescope oldfiles <CR>", "Search Recent Files" },
    	w = { "<cmd>cd ~/vimwiki/home | :Telescope live_grep theme=ivy<cr>", "Search Neorg Wiki" },
    }

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

    local function code_keymap()
    	if vim.fn.has("nvim-0.7") then
    		vim.api.nvim_create_autocmd("FileType", {
    			pattern = "*",
    			callback = function()
    				vim.schedule(CodeRunner)
    			end,
    		})
    	else
    		vim.cmd("autocmd FileType * lua CodeRunner()")
    	end

    	-- credit to https://alpha2phi.medium.com/neovim-for-beginners-lua-autocmd-and-keymap-functions-3bdfe0bebe42
    	function CodeRunner()
    		local bufnr = vim.api.nvim_get_current_buf()
    		local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    		local ncodemap = {}
    		local vcodemap = {}
    		local nnoleader = {}

    		if ft == "python" then
    			ncodemap = {
    				c = {
    					name = "Code",
    					["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    					t = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.python_job_id}<cr>", "Get Python REPL" },
    				},
    				-- TODO: Figure out how to switch between Slime and Conjure and keep the <leader><CR> for code execution
    				["<CR>"] = { ":MoltenEvaluateLine<CR>", "Execute Code Cell <marks>" },
    				-- ["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				["<S-CR>"] = { "ggvG :'<,'>SlimeSend<CR>", "Run Whole File" },
    			}
    			vcodemap = {
    				c = {
    					name = "Code",
    					["<CR>"] = { ":'<,'>ConjureEval<cr>", "Run Code w/ Conjure" },
    				},
    				["<CR>"] = { ":<C-u>MoltenEvaluateVisual<CR>", "Execute Selected Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    			}
    			-- nnoleader = {
    			-- 	["J"] = { ":IPythonCellNextCell<cr>", "Execute Line of Code" },
    			-- 	["K"] = { ":IPythonCellPrevCell<cr>", "Execute Line of Code" },
    			-- }
    		elseif ft == "julia" then
    			ncodemap = {
    				c = {
    					name = "Code",
    					t = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.julia_job_id}<cr>", "Get Julia REPL" },
    					["<CR>"] = { ":JuliaCellExecuteCell<CR>", "Run w/ Julia Cell / Slime" },
    				},
            d = {
              d = {
                ":call pluto#delete_cell()<CR>", "Delete Pluto Cell"
              }
            },
            y = {
              y = {
                ":call pluto#yank_cell()<CR>", "Yank Pluto Cell"
              }
            },
            O = {
              ":call pluto#insert_cell_above()<CR>", "Insert Pluto Cell Above"
            },
            o = {
              ":call pluto#insert_cell_below()<CR>", "Insert Pluto Cell Below"
            },
            P = {
              ":call pluto#paste_cell_above()<CR>", "Paste Pluto Cell Above"
            },
            p = {
              ":call pluto#paste_cell_below()<CR>", "Paste Pluto Cell Below"
            },

    				-- Slime is almost OBE because ToggleTerm does similr things but I'm keeping it
    				-- because of things like vim julia cell uses it and I like being able to do
    				-- code between marks
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				["<CR>"] = { ":MoltenEvaluateLine<CR>", "Execute Code" },
    				-- ["<CR>"] = { ":ConjureEvalCurrentForm<CR>", "Execute Code" },
    				-- ["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["<S-CR>"] = { "ggvG :<C-u>MoltenEvaluateVisual<CR>", "Run Whole File" },
    			}
    			vcodemap = {
    				c = {
    					name = "Code",
    					["<CR>"] = { ":'<,'>SlimeSend<CR>", "Run w/ Slime" },
    				},
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				["<CR>"] = { ":<C-u>MoltenEvaluateVisual<CR>", "Run Code w/ Conjure" },
    			}
    			-- nnoleader = {
    			-- 	["J"] = { ":JuliaCellNextCell<cr>", "Execute Line of Code" },
    			-- 	["K"] = { ":JuliaCellPrevCell<cr>", "Execute Line of Code" },
    			-- }
    		elseif ft == "clojure" then
    			ncodemap = {
    				c = {
    					name = "Code",
    					s = { "<cmd>call StartClojure()<cr>", "Start Clojure (clj)" },
    					["<CR>"] = { "(v%", "Visually Select ()" },
    					t = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.clojure_job_id}<cr>", "Get Clojure REPL" },
    				},
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				-- ["<CR>"] = { ":SlimeSendCurrentLine<cr>", "Execute Code" },
    				["<CR>"] = { ':ConjureEvalCurrentForm<CR>:silent! call repeat#set(" ee", 1)<CR>', "Execute Code" },
    				["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["<S-CR>"] = { "ggvG :'<,'>SlimeSend<CR>", "Run Whole File" },
    			}
    			vcodemap = {
    				c = {
    					name = "Code",
    					["<CR>"] = { ":'<,'>SlimeSend<CR>", "Run Code w/ Slime" },
    				},
    				["<CR>"] = { ':ConjureEvalCurrentForm<CR>:silent! call repeat#set(" ee", 1)<CR>', "Execute Code" },
    			}
    		elseif ft == "javascript" then
    			ncodemap = {
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				["<CR>"] = { ":SlimeSendCurrentLine<cr>", "Execute Code" },
    				["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["<S-CR>"] = { "ggvG :'<,'>SlimeSend<CR>", "Run Whole File" },
    				c = {
    					name = "Code",
    					t = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.node_job_id}<cr>", "Get Node REPL" },
    				},
    			}
    			vcodemap = {
    				["<CR>"] = { ":'<,'>SlimeSend<CR>", "Execute Selected Code" },
    			}
    		elseif ft == "lua" then
    			ncodemap = {
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				["<CR>"] = { "<cmd>luafile %<cr>", "Run" },
    				["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["<S-CR>"] = { "ggvG :'<,'>SlimeSend<CR>", "Run Whole File" },
    				c = {
    					name = "Code",
    					t = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.node_job_id}<cr>", "Get Node REPL" },
    				},
    			}
    			vcodemap = {
    				["<CR>"] = { ":'<,'>SlimeSend<CR>", "Execute Selected Code" },
    			}
    		elseif ft == "norg" then
          vnoleader = {
            ["<CR>"] = { ":<C-u>MoltenEvaluateVisual<CR>", "Execute Selected Code" },
          }
    			nnoleader = {
    				-- ["<CR>"] = {
    				-- 	":Neorg keybind all core.looking-glass.magnify-code-block<CR>",
    				-- 	"Execute Code?",
    				-- },
    			}
    			ncodemap = {
    				["<CR>"] = { ":MoltenEvaluateLine<CR>", "Execute Code" },
    				-- ["<CR>"] = {
    				-- 	":Neorg keybind all core.looking-glass.magnify-code-block<CR>",
    				-- 	"Execute Code?",
    				-- },
    				-- ["<CR>"] = {
    				-- 	-- ":normal S@c 1j V s@e 1k<CR>:'<,'>SlimeSend<CR>",
    				-- 	-- "<cmd>lua run_code_block()<cr>",
        --       ":MoltenEvaluateLine<CR>",
    				-- 	"Execute Code?",
    				-- },
    				["\\"] = { ":MoltenEvaluateLine<CR>", "Execute Line of Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				n = {
    					name = "Neorg",
    					i = { ":Neorg workspace home<cr>", "Home Index" },
    					w = { ":Neorg workspace work<cr>", "Work Index" },
    					v = { "<Cmd>Neorg gtd views<CR>", "GTD Views" },
    					c = { "<Cmd>Neorg gtd capture<CR>", "GTD Capture" },
    					e = { "<Cmd>Neorg gtd edit<CR>", "GTD Edit" },
    					p = { ":Neorg presenter start<cr>", "Start Presentation" },
    					n = { "<Cmd>Neorg keybind norg core.norg.dirman.new.note<CR>", "New Note" },
    					j = { ":Neorg journal today<cr>", "Today's Journal" },
    				},
    				c = {
    					name = "Code",
    					l = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.lua_job_id}<cr>", "Get Lua REPL" },
    					p = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.python_job_id}<cr>", "Get Python REPL" },
    					j = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.julia_job_id}<cr>", "Get Julia REPL" },
    					c = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.clojure_job_id}<cr>", "Get Clojure REPL" },
    					n = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.node_job_id}<cr>", "Get Node REPL" },
    				  g = {
    					":Neorg keybind all core.looking-glass.magnify-code-block<CR>",
    					"Open Looking Glass",
    				},
    				},
    			}
    			vcodemap = {
    				["<CR>"] = { ":<C-u>MoltenEvaluateVisual<CR>", "Execute Selected Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    			}
    		elseif ft == "markdown" then
    			ncodemap = {
    				-- ["<CR>"] = { ":SlimeSendCurrentLine<cr>", "Execute Code" },
    				["<CR>"] = {
    					-- ":normal S@c 1j V s@e 1k<CR>:'<,'>SlimeSend<CR>",
    					"<cmd>lua run_code_block()<cr>",
    					"Execute Code?",
    				},
    				["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    			}
    			vcodemap = {
    				["<CR>"] = { ":'<,'>SlimeSend<CR>", "Execute Selected Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    			}
    		elseif ft == "markdown" then
    			ncodemap = {
    				-- ["<CR>"] = { ":SlimeSendCurrentLine<cr>", "Execute Code" },
    				["<CR>"] = {
    					":FeMaco<CR>",
    					"Execute Code?",
    				},
    				["\\"] = { ":SlimeSendCurrentLine<cr>", "Execute Line of Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    				c = {
    					name = "Code",
    					l = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.lua_job_id}<cr>", "Get Lua REPL" },
    					p = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.python_job_id}<cr>", "Get Python REPL" },
    					j = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.julia_job_id}<cr>", "Get Julia REPL" },
    					c = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.clojure_job_id}<cr>", "Get Clojure REPL" },
    					n = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.node_job_id}<cr>", "Get Node REPL" },
    				},
    			}
    			vcodemap = {
    				["<CR>"] = { ":'<,'>SlimeSend<CR>", "Execute Selected Code" },
    				["?"] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP Hover Definition" },
    			}
    			-- elseif ft == "rust" then
    			--   keymap_c = {
    			--     name = "Code",
    			--     r = { "<cmd>Cargo run<cr>", "Run" },
    			--     D = { "<cmd>RustDebuggables<cr>", "Debuggables" },
    			--     h = { "<cmd>RustHoverActions<cr>", "Hover Actions" },
    			--     R = { "<cmd>RustRunnables<cr>", "Runnables" },
    			--   }
    			-- elseif ft == "go" then
    			--   keymap_c = {
    			--     name = "Code",
    			--     r = { "<cmd>GoRun<cr>", "Run" },
    			--   }
    			-- elseif ft == "typescript" or ft == "typescriptreact" or ft == "javascript" or ft == "javascriptreact" then
    			--   keymap_c = {
    			--     name = "Code",
    			--     o = { "<cmd>TSLspOrganize<cr>", "Organize" },
    			--     r = { "<cmd>TSLspRenameFile<cr>", "Rename File" },
    			--     i = { "<cmd>TSLspImportAll<cr>", "Import All" },
    			--     R = { "<cmd>lua require('config.test').javascript_runner()<cr>", "Choose Test Runner" },
    			--     s = { "<cmd>2TermExec cmd='yarn start'<cr>", "Yarn Start" },
    			--     t = { "<cmd>2TermExec cmd='yarn test'<cr>", "Yarn Test" },
    			--   }
    		end
    		if next(ncodemap) ~= nil then
    			which_key.register(
    				ncodemap,
    				{ mode = "n", silent = true, noremap = true, buffer = bufnr, prefix = "<leader>" }
    			)
    			which_key.register(
    				vcodemap,
    				{ mode = "v", silent = true, noremap = true, buffer = bufnr, prefix = "<leader>" }
    			)
    			which_key.register(nnoleader, { mode = "n", silent = true, noremap = true, buffer = bufnr })
          which_key.register(vnoleader, { mode = "v", silent = true, noremap = true, buffer = bufnr })
    		end
    	end
    end

    code_keymap()

  '';
}
