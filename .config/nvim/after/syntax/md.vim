" augroup pandoc_syntax
"     autocmd! BufReadPre,FileReadPre,BufFilePre,FileType *.md set syntax=markdown.pandoc filetype=markdown
"     au! BufNewFile,BufFilePre,BufRead *.md set syntax=markdown.pandoc let g:pandoc#filetypes#pandoc_markdown = 1
"     au! BufNewFile,BufFilePre,BufRead *.jmd set filetype=markdown.pandoc syntax=julia
"     autocmd! BufReadPre,FileReadPre,BufFilePre,FileType vimwiki set syntax=markdown.pandoc filetype=vimwiki
"     autocmd! BufReadPre,FileReadPre,BufFilePre,FileType *.md set syntax=markdown.pandoc filetype=vimwiki
" augroup END

