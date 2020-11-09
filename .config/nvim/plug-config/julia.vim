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
"
"
autocmd FileType julia :call LaTeXtoUnicode#Toggle()
" noremap <expr> <F7> LaTeXtoUnicode#Toggle()
" noremap! <expr> <F7> LaTeXtoUnicode#Toggle()

" inoremap <expr> <F7> LaTeXtoUnicode#Toggle()
" inoremap! <expr> <F7> LaTeXtoUnicode#Toggle()
" let g:latex_to_unicode_cmd_mapping = ['<C-j>']
" let g:julia_latex_to_unicode=0
" let g:julia_latex_suggestions_enabled=0
" let g:julia_auto_latex_to_unicode=0
" let g:latex_to_unicode_tab = 0

