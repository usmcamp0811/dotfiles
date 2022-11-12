local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
	return
end

local markid = require'markid'

markid.colors = {
    dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
    bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#98fc03" },
    medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
}

markid.queries = {
  default = '(identifier) @markid',
  javascript = [[
          (identifier) @markid
          (property_identifier) @markid
          (shorthand_property_identifier_pattern) @markid
        ]]
}
markid.queries.typescript = markid.queries.javascript

parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

-- This has some issue on unsteup systems.. its not installing correctly.. but it also doesn't seem necesary
-- parser_configs.markdown = {
--   install_info = {
--     url = "https://github.com/ikatyang/tree-sitter-markdown",
--     files = { "src/parser.c", "src/scanner.cc" },
--   },
--   filetype = { "vimwiki", "markdown" },
-- }

configs.setup({
	ensure_installed = "all", -- one of "all" or a list of languages
	ignore_install = { "" }, -- List of parsers to ignore installing
	highlight = {
		enable = true, -- false will disable the whole extension
		disable = { "css" }, -- list of language that will be disabled
		additional_vim_regex_highlighting = { "org", "norg" },
	},
	autopairs = {
		enable = true,
	},
	autotag = {
		enable = true,
		filetypes = {
			"html",
			"javascript",
			"typescript",
			"javascriptreact",
			"typescriptreact",
			"svelte",
			"vue",
			"tsx",
			"jsx",
			"rescript",
			"xml",
			"php",
			"markdown",
			"glimmer",
			"handlebars",
			"hbs",
			"julia",
      "norg",
		},
	},
	indent = { enable = true, disable = { "python", "css" } },
	parser_configs = parser_configs,
	textsubjects = {
		enable = true,
		prev_selection = ",", -- (Optional) keymap to select the previous selection
		keymaps = {
			["."] = "textsubjects-smart",
			[";"] = "textsubjects-container-outer",
			["i;"] = "textsubjects-container-inner",
		},
	},
  markid = {
    enable = true,
    colors = markid.colors.medium,
    queries = markid.queries,
    is_supported = function(lang)
      local queries = configs.get_module("markid").queries
      return pcall(vim.treesitter.parse_query, lang, queries[lang] or queries['default'])
    end
  }
})
