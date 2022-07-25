" vim-commentary "{{{
nnoremap <Bs> :Commentary<CR>
autocmd FileType apache setlocal commentstring=#\ %s
autocmd BufNewFile,BufRead *.Xresources set filetype=xdefaults
autocmd FileType xdefaults setlocal commentstring=!\ %s


" }}}
