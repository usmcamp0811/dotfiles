if has('nvim')
    let g:python3_host_prog = '/usr/local/bin/python3'
else
    set pyxversion=3
endif

let g:jupyter_mapkeys = 0
" Run current file
nnoremap <buffer> <silent> <localleader>f :JupyterRunFile<CR>
nnoremap <buffer> <silent> <localleader>e <Plug :JupyterImportThisFile<CR>

" Change to directory of current file
nnoremap <buffer> <silent> <localleader>d :JupyterCd %:p:h<CR>

" Send a selection of lines
nnoremap <buffer> <silent> <localleader>x :JupyterSendCell<CR>
nnoremap <buffer> <silent> <localleader>E :JupyterSendRange<CR>
" nmap     <buffer> <silent> <localleader>e <Plug>JupyterRunTextObj
" vmap     <buffer> <silent> <localleader>e <Plug>JupyterRunVisual

nnoremap <buffer> <silent> <localleader>U :JupyterUpdateShell<CR>

" Debugging maps
nnoremap <buffer> <silent> <localleader>b :PythonSetBreak<CR>
" autocmd FileType RMarkdown,julia,python call jupyter#MakeStandardCommands()
au BufNewFile,BufRead .Rmd,Rmd set filetype=RMarkdown
