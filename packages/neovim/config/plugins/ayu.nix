{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [neovim-ayu];
  extraConfigLua = ''

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

    local function set_colors(fg, bg)
    	return "guifg=" .. fg .. " guibg=" .. bg
    end
    --
    -- -- Applying colors
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
    api.nvim_command("hi WildMenu guifg=#0A0E14 guibg=#f07178")
    api.nvim_command("hi WildMenu guifg=#0A0E14 guibg=#f07178")
    api.nvim_command("hi @neorg.tags.ranged_verbatim.code_block guibg=#171717")
  '';
}
