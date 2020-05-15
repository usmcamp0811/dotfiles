if has('nvim')
    let g:python3_host_prog = '/usr/bin/python'
else
    set pyxversion=3
endif

let g:jupyter_mapkeys = 0
" Run current file
nnoremap <buffer> <silent> <c-f> :JupyterRunFile<CR>
nnoremap <buffer> <silent> <c-I> :JupyterImportThisFile<CR>

" Change to directory of current file
nnoremap <buffer> <silent> <c-d> :JupyterCd %:p:h<CR>

" Send a selection of lines
nnoremap <buffer> <silent> <c-x> :JupyterSendCell<CR>
nnoremap <buffer> <silent> <c-E> :JupyterSendRange<CR>
nmap     <buffer> <silent> <localleader>e <Plug>JupyterRunTextObj
vmap     <buffer> <silent> <localleader>e <Plug>JupyterRunVisual

nnoremap <buffer> <silent> <c-U> :JupyterUpdateShell<CR>

" Debugging maps
nnoremap <buffer> <silent> <c-b> :PythonSetBreak<CR>
autocmd FileType RMarkdown,julia,python call jupyter#MakeStandardCommands()
au BufNewFile,BufRead .Rmd,Rmd set filetype=RMarkdown
