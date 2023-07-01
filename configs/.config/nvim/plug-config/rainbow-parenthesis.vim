" RainbowParenthesis.vim {{{
" Activation based on file type
autocmd FileType * RainbowParentheses
let g:rainbow#max_level = 16
let g:rainbow#pairs = [['(', ')'], ['[', ']'], ['{', '}']]

" }}}
