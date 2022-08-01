vim.g.auto_save = 1
-- vim.g.auto_save_events = {"InsertLeave", "TextChangedI", "CompleteDone", "TextChanged"}
vim.g.auto_save_silent = 1

vim.cmd [[
  augroup ft_auto_saves
    au!
    au FileType markdown let b:auto_save = 1
    au FileType python let b:auto_save = 1
    au FileType julia let b:auto_save = 1
    au FileType go let b:auto_save = 1
    au FileType css let b:auto_save = 1
    au FileType json let b:auto_save = 1
    au FileType java let b:auto_save = 1
    au FileType html let b:auto_save = 1
    au FileType r let b:auto_save = 1
    au FileType scss let b:auto_save = 1 
    au FileType sql let b:auto_save = 1  
    au FileType sh let b:auto_save = 1  
    au FileType dockerfile let b:auto_save = 1  
    au FileType javascript let b:auto_save = 1  
    au FileType vue let b:auto_save = 0
    au FileType vim let b:auto_save = 1
    au FileType rmd let b:auto_save = 1
    au FileType tex let b:auto_save = 1
    au FileType lua let b:auto_save = 1
    au FileType md let b:auto_save = 1
    au FileType vimwiki let b:auto_save = 1
    au BufWinEnter plugins.lua let b:auto_save = 0
  
  augroup END
]]
