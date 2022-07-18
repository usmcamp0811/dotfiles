vim.cmd [[
try
  colorscheme darkburn
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme default
  set background=dark
endtry
]]
