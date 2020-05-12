" Configuring Julia
let g:notebook_cmd='/usr/bin/julia -qi'
let g:notebook_stop='exit()'
let g:notebook_send0=""
let g:notebook_send='println(); println(\"VIMJULIANOTEBOOK\")'
let g:notebook_detect='VIMJULIANOTEBOOK'

" adding ntoebook menu
map ~ :emenu Notebook.<C-Z>
" run code
map <S-CR> :NotebookEvaluate<CR>
" }}}
