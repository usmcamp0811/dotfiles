augroup pandoc_syntax
  " au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
  autocmd! FileType vimwiki set syntax=markdown.pandoc
  autocmd! FileType markdown set syntax=markdown.pandoc
augroup END
