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
