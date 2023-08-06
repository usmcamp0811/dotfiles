vim.cmd [[
try
  let g:catppuccin_flavour = "mocha" " latte, frappe, macchiato, mocha
  colorscheme catppuccin
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme auto
  set background=dark
endtry
]]

