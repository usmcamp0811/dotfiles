require('ayu').setup({
    mirage = false, -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
    overrides = {}, -- A dictionary of group names, each associated with a dictionary of parameters (`bg`, `fg`, `sp` and `style`) and colors in hex.
})

vim.cmd([[
try
  colorscheme ayu
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme auto
  set background=dark
endtry
]])

-- Ayu
local colors = {}
colors.accent = "#E6B450"
colors.bg = "#0A0E14"
colors.fg = "#B3B1AD"
colors.ui = "#4D5566"

colors.tag = "#39BAE6"
colors.func = "#FFB454"
colors.entity = "#59C2FF"
colors.string = "#C2D94C"
colors.regexp = "#95E6CB"
colors.markup = "#F07178"
colors.keyword = "#FF8F40"
colors.special = "#E6B673"
colors.comment = "#626A73"
colors.constant = "#FFEE99"
colors.operator = "#F29668"
colors.error = "#FF3333"

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
colors.warning = "#FF8F40"

local function set_colors(fg, bg)
	return "guifg=" .. fg .. " guibg=" .. bg
end
-- 
-- -- Applying colors
local api = vim.api
api.nvim_command("hi StatusDefault " .. set_colors(colors.fg, colors.bg))
api.nvim_command("hi StatusVimNormal " .. set_colors(colors.bg, colors.accent))
-- api.nvim_command("hi StatusVimInsert " .. set_colors(colors.bg, colors.neutral_blue))
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
-- api.nvim_command("hi StatusGitInfo " .. set_colors(colors.bright_green, colors.bg))
-- api.nvim_command("hi StatusLSPProgress " .. set_colors(colors.neutral_blue, colors.bg))
-- api.nvim_command("hi StatusLSPError " .. set_colors(colors.error, colors.bg))
-- api.nvim_command("hi StatusLSPWarn " .. set_colors(colors.accent, colors.bg))
-- api.nvim_command("hi StatusLSPInfo " .. set_colors(colors.entity, colors.bg))
-- api.nvim_command("hi StatusLSPHin " .. set_colors(colors.tag, colors.bg))
-- api.nvim_command("hi StatusLSPStatus " .. set_colors(colors.tag, colors.bg))
-- api.nvim_command("hi StatusCwd " .. set_colors(colors.keyword, colors.bg))
-- api.nvim_command("hi StatusCursor " .. set_colors(colors.accent, colors.bg))
-- api.nvim_command("hi WhichKeyFloat " .. set_colors(colors.accent, colors.bg))
-- api.nvim_command("hi SessionName " .. set_colors(colors.string, colors.bg))

