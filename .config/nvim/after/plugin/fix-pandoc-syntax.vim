augroup pandoc_syntax
  " au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
  autocmd! FileType vimwiki set syntax=markdown.pandoc
  autocmd! FileType markdown set syntax=markdown.pandoc
  autocmd FileType markdown lua require('literate')
  autocmd FileType vimwiki lua require('literate')
augroup END
