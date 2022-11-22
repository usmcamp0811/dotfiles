
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
