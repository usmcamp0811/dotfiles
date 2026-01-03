require("eza-preview"):setup({
	level = 2,
	follow_symlinks = true,
	dereference = true,
})
require("full-border"):setup()

-- require("fg"):setup({
-- 	default_action = "menu", -- nvim, jump
-- })

-- require("githead"):setup()

require("git"):setup()

-- DuckDB plugin configuration
require("duckdb"):setup({
	mode = "standard", -- Default: "summarized"
	row_id = true, -- Default: false
	minmax_column_width = 30, -- Default: 21
})

-- require("bunny"):setup({
-- 	hops = {
-- 		{ key = "r", path = "/" },
-- 		{ key = "v", path = "/var" },
-- 		{ key = "t", path = "/tmp" },
-- 		{ key = "c", path = "/config", desc = "Nix Config" },
-- 		{ key = { "n", "n" }, path = "/nix/store", desc = "Nix store" },
-- 		{ key = { "n", "v" }, path = "~/code/campground-nvim", desc = "Nvim Config" },
-- 		{ key = { "h", "h" }, path = "~", desc = "Home" },
-- 		{ key = { "h", "c" }, path = "~/code", desc = "Code" },
-- 		{ key = { "h", "w" }, path = "~/work-code", desc = "Work Code" },
-- 		{ key = { "h", "d" }, path = "~/Documents", desc = "Documents" },
-- 	},
-- 	desc_strategy = "path",
-- 	notify = false,
-- 	fuzzy_cmd = "fzf",
-- })

local catppuccin_theme = require("yatline-catppuccin"):setup("mocha")
require("yatline"):setup({
	theme = catppuccin_theme,
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },

	style_a = {
		fg = "black",
		bg_mode = {
			normal = "white",
			select = "brightyellow",
			un_set = "brightred",
		},
	},
	style_b = { bg = "brightblack", fg = "brightwhite" },
	style_c = { bg = "black", fg = "brightwhite" },

	permissions_t_fg = "green",
	permissions_r_fg = "yellow",
	permissions_w_fg = "red",
	permissions_x_fg = "cyan",
	permissions_s_fg = "white",

	tab_width = 20,
	tab_use_inverse = false,

	selected = { icon = "󰻭", fg = "yellow" },
	copied = { icon = "", fg = "green" },
	cut = { icon = "", fg = "red" },

	total = { icon = "󰮬", fg = "yellow" },
	succ = { icon = "", fg = "green" },
	fail = { icon = "", fg = "red" },
	found = { icon = "󰮕", fg = "blue" },
	processed = { icon = "󰐍", fg = "green" },

	show_background = true,

	display_header_line = true,
	display_status_line = true,

	component_positions = { "header", "tab", "status" },

	header_line = {
		left = {
			section_a = {
				{ type = "line", custom = false, name = "tabs", params = { "left" } },
			},
			section_b = {},
			section_c = {},
		},
		right = {
			section_a = {
				{ type = "string", custom = false, name = "date", params = { "%A, %d %B %Y" } },
			},
			section_b = {
				{ type = "string", custom = false, name = "date", params = { "%X" } },
			},
			section_c = {},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", custom = false, name = "tab_mode" },
			},
			section_b = {
				{ type = "string", custom = false, name = "hovered_size" },
			},
			section_c = {
				{ type = "string", custom = false, name = "hovered_path" },
				{ type = "coloreds", custom = false, name = "count" },
			},
		},
		right = {
			section_a = {
				{ type = "string", custom = false, name = "cursor_position" },
			},
			section_b = {
				{ type = "string", custom = false, name = "cursor_percentage" },
			},
			section_c = {
				{ type = "string", custom = false, name = "hovered_file_extension", params = { true } },
				{ type = "coloreds", custom = false, name = "permissions" },
			},
		},
	},
})
