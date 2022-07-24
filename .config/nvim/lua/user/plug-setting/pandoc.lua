
vim.cmd[[
augroup pandoc_syntax
    autocmd! BufReadPre,FileReadPre,BufFilePre,FileType *.md set syntax=markdown.pandoc filetype=markdown
    au! BufNewFile,BufFilePre,BufRead *.md set syntax=markdown.pandoc let g:pandoc#filetypes#pandoc_markdown = 1
    au! BufNewFile,BufFilePre,BufRead *.jmd set filetype=markdown.pandoc syntax=julia
    autocmd! BufReadPre,FileReadPre,BufFilePre,FileType vimwiki set syntax=markdown.pandoc filetype=vimwiki
    autocmd! BufReadPre,FileReadPre,BufFilePre,FileType *.md set syntax=markdown.pandoc filetype=vimwiki
augroup END
]]

vim.g["pandoc#syntax#codeblocks#embeds#langs"] = {"python", "julia", "bash=sh", "json=javascript", "javascript", "clojure", "zsh=sh", "dockerfile"}
vim.g["pandoc#syntax#conceal#urls"] = 1
-- vim.g["pandoc#folding#mode"] = {'manual'}
vim.g["pandoc#folding#fdc"] = 0


