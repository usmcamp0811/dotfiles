" range in vim
" let g:NERDTreeHijackNetrw = 0 // add this line if you use NERDTree
" let g:ranger_replace_netrw = 1 // open ranger when vim open a directory
let g:ranger_command_override = 'ranger --cmd "set show_hidden=true"'
silent! nmap <F2> :Ranger<CR>
