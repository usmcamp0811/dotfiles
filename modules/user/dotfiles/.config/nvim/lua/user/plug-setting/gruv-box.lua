require("gruvbox").setup({
	undercurl = true,
	underline = true,
	bold = true,
	italic = true,
	strikethrough = true,
	invert_selection = false,
	invert_signs = false,
	invert_tabline = false,
	invert_intend_guides = false,
	inverse = true, -- invert background for search, diffs, statuslines and errors
	contrast = "hard", -- can be "hard", "soft" or empty string
	overrides = {},
	dim_inactive = false,
	transparent_mode = false,
	palette_overrides = {
		dark0_hard = "#0A0E14",
		dark0 = "#282828",
		dark0_soft = "#32302f",
		dark1 = "#00010A",
		dark2 = "#504945",
		dark3 = "#665c54",
		dark4 = "#7c6f64",
		light0_hard = "#f9f5d7",
		light0 = "#fbf1c7",
		light0_soft = "#f2e5bc",
		light1 = "#ebdbb2",
		light2 = "#d5c4a1",
		light3 = "#bdae93",
		light4 = "#a89984",
		bright_red = "#fb4934",
		bright_green = "#b8bb26",
		bright_yellow = "#fabd2f",
		bright_blue = "#83a598",
		bright_purple = "#d3869b",
		bright_aqua = "#8ec07c",
		bright_orange = "#fe8019",
		neutral_red = "#cc241d",
		neutral_green = "#98971a",
		neutral_yellow = "#d79921",
		neutral_blue = "#458588",
		neutral_purple = "#b16286",
		neutral_aqua = "#689d6a",
		neutral_orange = "#d65d0e",
		faded_red = "#9d0006",
		faded_green = "#79740e",
		faded_yellow = "#b57614",
		faded_blue = "#076678",
		faded_purple = "#8f3f71",
		faded_aqua = "#427b58",
		faded_orange = "#af3a03",
		gray = "#928374",
	},
})


-- Gruvbox: Custom hehe
local colors = {}
colors.accent = "#fabd2f"
colors.bg = "#0A0E14"
colors.fg = "#B3B1AD"
colors.ui = "#4D5566"

colors.tag = "#076678"
colors.func = "#d79921"
colors.entity = "#458588"
colors.string = "#8ec07c"
colors.regexp = "#427b58"
colors.markup = "#fb4934"
colors.keyword = "#FF8F40"
colors.special = "#b57614"
colors.comment = "#626A73"
colors.constant = "#f2e5bc"
colors.operator = "#fe8019"
colors.error = "#cc241d"

colors.line = "#00010A"
colors.panel_bg = "#0D1016"
colors.panel_shadow = "#00010A"
colors.panel_border = "#000000"
colors.gutter_normal = "#323945"
colors.gutter_active = "#464D5E"
colors.selection_bg = "#273747"
colors.selection_inactive = "#1B2733"
colors.selection_border = "#304357"
colors.guide_active = "#393F4D"
colors.guide_normal = "#242A35"

colors.vcs_added = "#91B362"
colors.vcs_modified = "#6994BF"
colors.vcs_removed = "#D96C75"

colors.vcs_added_bg = "#1D2214"
colors.vcs_removed_bg = "#2D2220"

colors.fg_idle = "#3E4B59"
colors.warning = "#fe8019"

-- Colors

colors.dark0_hard = "#0A0E14"
colors.dark0 = "#282828"
colors.dark0_soft = "#32302f"
colors.dark1 = "#00010A"
colors.dark2 = "#504945"
colors.dark3 = "#665c54"
colors.dark4 = "#7c6f64"
colors.light0_hard = "#f9f5d7"
colors.light0 = "#fbf1c7"
colors.light0_soft = "#f2e5bc"
colors.light1 = "#ebdbb2"
colors.light2 = "#d5c4a1"
colors.light3 = "#bdae93"
colors.light4 = "#a89984"
colors.bright_red = "#fb4934"
colors.bright_green = "#b8bb26"
colors.bright_yellow = "#fabd2f"
colors.bright_blue = "#83a598"
colors.bright_purple = "#d3869b"
colors.bright_aqua = "#8ec07c"
colors.bright_orange = "#fe8019"
colors.neutral_red = "#cc241d"
colors.neutral_green = "#98971a"
colors.neutral_yellow = "#d79921"
colors.neutral_blue = "#458588"
colors.neutral_purple = "#b16286"
colors.neutral_aqua = "#689d6a"
colors.neutral_orange = "#d65d0e"
colors.faded_red = "#9d0006"
colors.faded_green = "#79740e"
colors.faded_yellow = "#b57614"
colors.faded_blue = "#076678"
colors.faded_purple = "#8f3f71"
colors.faded_aqua = "#427b58"
colors.faded_orange = "#af3a03"
colors.gray = "#928374"


-- Theme: If you want to change the theme you need to
-- change this 2 things, colorscheme will apply the theme in the IDE
-- and you will also need to create a theme_colors to apply the theme
-- to the statusline and whichkey
local colorscheme = "gruvbox"

local function set_colors(fg, bg)
	return "guifg=" .. fg .. " guibg=" .. bg
end

-- Applying colors
local api = vim.api
api.nvim_command("hi StatusDefault " .. set_colors(colors.fg, colors.bg))
api.nvim_command("hi StatusVimNormal " .. set_colors(colors.bg, colors.accent))
api.nvim_command("hi StatusVimInsert " .. set_colors(colors.bg, colors.neutral_blue))
api.nvim_command("hi StatusVimVisual " .. set_colors(colors.bg, colors.func))
api.nvim_command("hi StatusVimReplace " .. set_colors(colors.bg, colors.entity))
api.nvim_command("hi StatusVimEnter " .. set_colors(colors.bg, colors.string))
api.nvim_command("hi StatusVimMore " .. set_colors(colors.bg, colors.regexp))
api.nvim_command("hi StatusVimSelect " .. set_colors(colors.bg, colors.markup))
api.nvim_command("hi StatusVimCmd " .. set_colors(colors.bg, colors.keyword))
api.nvim_command("hi StatusVimShell " .. set_colors(colors.bg, colors.special))
api.nvim_command("hi StatusVimTerm " .. set_colors(colors.bg, colors.comment))
api.nvim_command("hi StatusModified " .. set_colors(colors.bg, colors.constant))
api.nvim_command("hi StatusLineNumber " .. set_colors(colors.bg, colors.operator))
api.nvim_command("hi StatusColumnNumber " .. set_colors(colors.bg, colors.error))
api.nvim_command("hi StatusFileInfo " .. set_colors(colors.keyword, colors.bg))
api.nvim_command("hi StatusGitInfo " .. set_colors(colors.bright_green, colors.bg))
api.nvim_command("hi StatusLSPProgress " .. set_colors(colors.neutral_blue, colors.bg))
api.nvim_command("hi StatusLSPError " .. set_colors(colors.error, colors.bg))
api.nvim_command("hi StatusLSPWarn " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi StatusLSPInfo " .. set_colors(colors.entity, colors.bg))
api.nvim_command("hi StatusLSPHin " .. set_colors(colors.tag, colors.bg))
api.nvim_command("hi StatusLSPStatus " .. set_colors(colors.tag, colors.bg))
api.nvim_command("hi StatusCwd " .. set_colors(colors.keyword, colors.bg))
api.nvim_command("hi StatusCursor " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi WhichKeyFloat " .. set_colors(colors.accent, colors.bg))
api.nvim_command("hi SessionName " .. set_colors(colors.string, colors.bg))

local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
if not status_ok then
	vim.notify("colorscheme " .. colorscheme .. " not found!")
	return
end
