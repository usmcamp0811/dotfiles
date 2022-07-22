vim.g.catppuccin_flavour = "mocha"
local colors = require("catppuccin.palettes").get_palette()
colors.none = "NONE"
require("catppuccin").setup({
	dim_inactive = {
		enabled = true,
		shade = "dark",
		percentage = 0.15,
	},
	transparent_background = false,
	term_colors = false,
	compile = {
		enabled = true,
		path = vim.fn.stdpath "cache" .. "/catppuccin",
	},
	styles = {
		comments = { "italic" },
		conditionals = { "italic" },
		loops = {},
		functions = {},
		keywords = {},
		strings = {},
		variables = {},
		numbers = {},
		booleans = {},
		properties = {},
		types = {},
		operators = {},
	},
	integrations = {
		treesitter = true,
		native_lsp = {
			enabled = true,
			virtual_text = {
				errors = { "italic" },
				hints = { "italic" },
				warnings = { "italic" },
				information = { "italic" },
			},
			underlines = {
				errors = { "underline" },
				hints = { "underline" },
				warnings = { "underline" },
				information = { "underline" },
			},
		},
		coc_nvim = false,
		lsp_trouble = true,
		cmp = true,
		lsp_saga = false,
		gitgutter = false,
		gitsigns = true,
		leap = false,
		telescope =  true,
		nvimtree = {
			enabled = true,
			show_root = true,
			transparent_panel = true,
		},
		neotree = {
			enabled = false,
			show_root = true,
			transparent_panel = false,
		},
		dap = {
			enabled = false,
			enable_ui = false,
		},
		which_key = true,
		indent_blankline = {
			enabled = true,
			colored_indent_levels = true,
		},
		dashboard = true,
		neogit = false,
		vim_sneak = true,
		fern = false,
		barbar = false,
		bufferline = true,
		markdown = true,
		lightspeed = false,
		ts_rainbow = false,
		hop = false,
		notify = true,
		telekasten = true,
		symbols_outline = true,
		mini = false,
		aerial = false,
		vimwiki = false,
		beacon = true,
	},
	custom_highlights = {
		Comment = { fg = colors.overlay1 },
		LineNr = { fg = colors.overlay1 },
		CursorLine = { bg = colors.none },
		CursorLineNr = { fg = colors.lavender },
		DiagnosticVirtualTextError = { bg = colors.none },
		DiagnosticVirtualTextWarn = { bg = colors.none },
		DiagnosticVirtualTextInfo = { bg = colors.none },
		DiagnosticVirtualTextHint = { bg = colors.none },
	},
})

vim.cmd [[
try
  colorscheme catppuccin
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme auto
  set background=dark
endtry
]]
