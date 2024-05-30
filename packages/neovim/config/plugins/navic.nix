{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [nvim-navic];

  extraConfigLua = ''
    local navic = require("nvim-navic")

    navic.setup({
        icons = {
            File          = "󰇊 ",
            Module        = " ",
            Namespace     = "󰇊 ",
            Package       = " ",
            Class         = "󰇊 ",
            Method        = "󰇊 ",
            Property      = " ",
            Field         = " ",
            Constructor   = " ",
            Enum          = "󰇊",
            Interface     = "󰇊",
            Function      = "󰇊 ",
            Variable      = "󰇊 ",
            Constant      = "󰇊 ",
            String        = " ",
            Number        = "󰇊 ",
            Boolean       = "◩ ",
            Array         = "󰇊 ",
            Object        = "󰇊 ",
            Key           = "󰇊 ",
            Null          = "󰇊 ",
            EnumMember    = " ",
            Struct        = "󰇊 ",
            Event         = " ",
            Operator      = "󰇊 ",
            TypeParameter = "󰇊 ",
        },
        highlight = true,
        separator = " > ",
        depth_limit = 4,
        depth_limit_indicator = "...",
        safe_output = true
    })
  '';
}
