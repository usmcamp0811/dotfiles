require("eza-preview"):setup({
	level = 2,
	follow_symlinks = true,
	dereference = true,
})
require("full-border"):setup()

require("fg"):setup({
	default_action = "menu", -- nvim, jump
})

require("githead"):setup()

require("git"):setup()

-- DuckDB plugin configuration
require("duckdb"):setup({
	mode = "standard", -- Default: "summarized"
	row_id = true, -- Default: false
	minmax_column_width = 30, -- Default: 21
})

require("yaziline"):setup({
	color = "#98c379", -- main theme color
	separator_style = "angly", -- "angly" | "curvy" | "liney" | "empty"
	separator_open = "",
	separator_close = "",
	separator_open_thin = "",
	separator_close_thin = "",
	separator_head = "",
	separator_tail = "",
	select_symbol = "",
	yank_symbol = "󰆐",
	filename_max_length = 24, -- truncate when filename > 24
	filename_truncate_length = 6, -- leave 6 chars on both sides
	filename_truncate_separator = "...", -- the separator of the truncated filename
})

require("bunny"):setup({
	hops = {
		{ key = "r", path = "/" },
		{ key = "v", path = "/var" },
		{ key = "t", path = "/tmp" },
		{ key = "c", path = "/config", desc = "Nix Config" },
		{ key = "N", path = "/nix/store", desc = "Nix store" },
		{ key = "n", path = "~/code/campground-nvim", desc = "Nvim Config" },
		{ key = { "h", "h" }, path = "~", desc = "Home" },
		{ key = { "h", "c" }, path = "~/code", desc = "Code" },
		{ key = { "h", "w" }, path = "~/work-code", desc = "Work Code" },
		{ key = { "h", "d" }, path = "~/Documents", desc = "Documents" },
		-- key and path attributes are required, desc is optional
	},
	desc_strategy = "path", -- If desc isn't present, use "path" or "filename", default is "path"
	notify = false, -- Notify after hopping, default is false
	fuzzy_cmd = "fzf", -- Fuzzy searching command, default is "fzf"
})
