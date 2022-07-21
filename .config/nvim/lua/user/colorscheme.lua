vim.cmd [[
try
  colorscheme kanagawa
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme auto
  set background=dark
endtry
]]
