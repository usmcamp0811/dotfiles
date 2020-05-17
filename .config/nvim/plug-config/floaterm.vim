let g:floaterm_keymap_toggle = '<F1>'
let g:floaterm_keymap_next   = '<F2>'
let g:floaterm_keymap_prev   = '<F3>'
let g:floaterm_keymap_new    = '<F4>'

" Floaterm
let g:floaterm_gitcommit='floaterm'
let g:floaterm_autoinsert=1
let g:floaterm_width=0.8
let g:floaterm_height=0.8
let g:floaterm_wintitle=0
let g:floaterm_autoclose=1

let g:which_key_map.t = {
      \ 'name' : '+terminal' ,
      \ ';' : [':FloatermNew --wintype=popup --height=6'        , 'terminal'],
      \ 'f' : [':FloatermNew fzf'                               , 'fzf'], 
      \ 'g' : [':FloatermNew lazygit'                           , 'git'], 
      \ 'd' : [':FloatermNew lazydocker'                        , 'docker'], 
      \ 'n' : [':FloatermNew node'                              , 'node'], 
      \ 'N' : [':FloatermNew nnn'                               , 'nnn'], 
      \ 'p' : [':FloatermNew python'                            , 'python'], 
      \ 'r' : [':FloatermNew ranger'                            , 'ranger'], 
      \ 't' : [':FloatermToggle'                                , 'toggle'], 
      \ 'y' : [':FloatermNew ytop'                              , 'ytop'], 
      \ 's' : [':FloatermNew ncdu'                              , 'ncdu'], 
      \ }

