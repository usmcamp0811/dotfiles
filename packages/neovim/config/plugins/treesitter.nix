{ pkgs, ... }: {
  extraPlugins = with pkgs.vimPlugins; [ rnvimr markid ];
  plugins = {
    treesitter = {
      # enable = true;
      settings = { indent.enable = true; };
      nixvimInjections = true;
    };
    # treesitter-context.enable = true;
    # treesitter-refactor.enable = true;
    #    rainbow-delimiters = {
    #      enable = true; # Enable the plugin

    #      query = "rainbow-parens"; # Query for finding delimiters
    #      strategy = "require('ts-rainbow').strategy.global"; # Strategy for finding delimiters
    #      hlgroups = [
    #        "TSRainbowRed"
    #        "TSRainbowYellow"
    #        "TSRainbowBlue"
    #        "TSRainbowOrange"
    #        "TSRainbowGreen"
    #        "TSRainbowViolet"
    #        "TSRainbowCyan"
    #      ]; # Highlight groups to apply
    #    };
  };
  # extraConfigLua = ''
  #   local status_ok, configs = pcall(require, "nvim-treesitter.configs")
  #   if not status_ok then return
  #   end
  #
  #   local status_ok, markid = pcall(require, "markid")
  #   if not status_ok then
  #   	return
  #   end
  #
  #   markid.colors = {
  #       dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
  #       bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#98fc03" },
  #       medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
  #   }
  #
  #   markid.queries = {
  #     default = '(identifier) @markid',
  #     javascript = [[
  #             (identifier) @markid
  #             (property_identifier) @markid
  #             (shorthand_property_identifier_pattern) @markid
  #           ]]
  #   }
  #   markid.queries.typescript = markid.queries.javascript
  #
  #
  #   parser_configs = require("nvim-treesitter.parsers").get_parser_configs()
  #
  #   -- This has some issue on unsteup systems.. its not installing correctly.. but it also doesn't seem necesary
  #   -- parser_configs.markdown = {
  #   --   install_info = {
  #   --     url = "https://github.com/ikatyang/tree-sitter-markdown",
  #   --     files = { "src/parser.c", "src/scanner.cc" },
  #   --   },
  #   --   filetype = { "vimwiki", "markdown" },
  #   -- }
  #
  #   configs.setup({
  #   	highlight = {
  #   		enable = true, -- false will disable the whole extension
  #   		disable = { "css" }, -- list of language that will be disabled
  #   		additional_vim_regex_highlighting = { "org", "norg" },
  #   	},
  #   	autopairs = {
  #   		enable = true,
  #   	},
  #   	autotag = {
  #   		enable = true,
  #   		filetypes = {
  #   			"html",
  #   			"javascript",
  #   			"typescript",
  #   			"javascriptreact",
  #   			"typescriptreact",
  #   			"svelte",
  #   			"vue",
  #   			"tsx",
  #   			"jsx",
  #   			"rescript",
  #   			"xml",
  #   			"php",
  #   			"markdown",
  #   			"glimmer",
  #   			"handlebars",
  #   			"hbs",
  #   			"julia",
  #         "norg",
  #   		},
  #   	},
  #   	indent = { enable = true, disable = { "python", "css" } },
  #   	parser_configs = parser_configs,
  #   	textsubjects = {
  #   		enable = true,
  #   		prev_selection = ",", -- (Optional) keymap to select the previous selection
  #   		keymaps = {
  #   			["."] = "textsubjects-smart",
  #   			[";"] = "textsubjects-container-outer",
  #   			["i;"] = "textsubjects-container-inner",
  #   		},
  #   	},
  #     rainbow = {
  #       enable = true,
  #       extended_mode = true
  #     },
  #      markid = {
  #        enable = true,
  #        colors = markid.colors.bright,
  #        queries = markid.queries,
  #        is_supported = function(lang)
  #          local queries = configs.get_module("markid").queries
  #          return pcall(vim.treesitter.query.parse, lang, queries[lang] or queries['default'])
  #        end
  #      },
  #    textobjects = {
  #       select = {
  #         enable = true,
  #
  #         -- Automatically jump forward to textobj, similar to targets.vim
  #         lookahead = true,
  #
  #         keymaps = {
  #           -- You can use the capture groups defined in textobjects.scm
  #           ["af"] = "@function.outer",
  #           ["if"] = "@function.inner",
  #           ["ac"] = "@class.outer",
  #           ["ae"] = "@call.outer",
  #           ["ie"] = "@call.inner",
  #           ["ib"] = "@code",
  #           ["ag"] = "@def",
  #           -- You can optionally set descriptions to the mappings (used in the desc parameter of
  #           -- nvim_buf_set_keymap) which plugins like which-key display
  #           ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
  #         },
  #         -- You can choose the select mode (default is charwise 'v')
  #         --
  #         -- Can also be a function which gets passed a table with the keys
  #         -- * query_string: eg '@function.inner'
  #         -- * method: eg 'v' or 'o'
  #         -- and should return the mode ('v', 'V', or '<c-v>') or a table
  #         -- mapping query_strings to modes.
  #         selection_modes = {
  #           ['@parameter.outer'] = 'v', -- charwise
  #           ['@function.outer'] = 'V', -- linewise
  #           ['@class.outer'] = '<c-v>', -- blockwise
  #           ['@call.outer'] = 'v', -- charwise
  #         },
  #         -- If you set this to `true` (default is `false`) then any textobject is
  #         -- extended to include preceding or succeeding whitespace. Succeeding
  #         -- whitespace has priority in order to act similarly to eg the built-in
  #         -- `ap`.
  #         --
  #         -- Can also be a function which gets passed a table with the keys
  #         -- * query_string: eg '@function.inner'
  #         -- * selection_mode: eg 'v'
  #         -- and should return true of false
  #         include_surrounding_whitespace = true,
  #       },
  #     },
  #   })
  # '';
}
