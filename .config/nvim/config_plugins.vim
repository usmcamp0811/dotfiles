" TODO: break up into multiple files

" NERDTree {{{
"
" Toggle Tree View
silent! nmap <F3> :NERDTreeToggle<CR>
" open a NERDTree automatically when vim starts up if no files were specified {{{
autocmd StdinReadPre * let s:std_in=1
let NERDTreeShowHidden=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
" }}}
" open NERDTree automatically when vim starts up on  opening a directory {{{
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | exe 'cd '.argv()[0] | endif
" }}}
" close vim if the only window left open is a NERDTree {{{
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
" }}}
" }}}

" Syntastic.vim {{{
augroup syntastic_config
    autocmd!
    let g:syntastic_error_symbol = '✗'
    let g:syntastic_warning_symbol = '⚠'

    " Like Syntastic's pyflakes checker, but treats messages about  unused
    " variables/imports as warnings rather than errors.
    let g:syntastic_python_checkers = ['pyflakes_with_warnings']
    let g:syntastic_yaml_checkers = ['pyyaml']
    let g:syntastic_javascript_checkers = ['json_tool']
    let g:syntastic_json_checkers = ['json_tool']
augroup END
" }}}

" RainbowParenthesis.vim {{{
augroup rainbow_parenthesis_config
    autocmd!
    nnoremap <leader>rp :RainbowParenthesesToggle<CR>
augroup END
" }}}

" EasyAlign.vim {{{
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" augroup easy_align_config
"     autocmd!
"     vmap <Enter> <Plug>(EasyAlign) " Start interactive EasyAlign in visual mode (e.g. vip<Enter>)
"     nmap <Leader>a <Plug>(EasyAlign) " Start interactive EasyAlign for a motion/text object (e.g. <Leader>aip)
" augroup END
" }}}

" Airline.vim {{{
augroup airline_config
  autocmd!
  let g:airline_powerline_fonts = 1
  let g:airline_enable_syntastic = 1
  let g:airline#extensions#tabline#buffer_nr_format = '%s '
  let g:airline#extensions#tabline#buffer_nr_show = 1
  let g:airline#extensions#tabline#enabled = 1
  let g:airline#extensions#tabline#fnamecollapse = 0
  let g:airline#extensions#tabline#fnamemod = ':t'
augroup END

let g:airline_theme='cobalt2' " <theme> is a valid theme name
" }}}

" Using Emojis as Git Gutter symbols {{{

" if emoji#available()
"     let g:gitgutter_sign_added = emoji#for('small_blue_diamond')
"     let g:gitgutter_sign_modified = emoji#for('small_orange_diamond')
"     let g:gitgutter_sign_removed = emoji#for('small_red_triangle')
"     let g:gitgutter_sign_modified_removed = emoji#for('collision')
" endif
" }}}


" UltiSnips {{{
" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
" let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-l>"
let g:UltiSnipsJumpBackwardTrigger="<c-h>"
let g:UltiSnipsExpandTrigger="<C-j>"
" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"
" }}}

" Vim AutoSave {{{
" let g:auto_save = 1  " enable AutoSave on Vim startup
let g:auto_save = 0
augroup ft_auto_saves
  au!
  au FileType markdown let b:auto_save = 1
  au FileType python let b:auto_save = 1
  au FileType css let b:auto_save = 1
  au FileType json let b:auto_save = 1
  au FileType java let b:auto_save = 1
  au FileType html let b:auto_save = 1
  au FileType r let b:auto_save = 1
  au FileType scss let b:auto_save = 1 
  au FileType sql let b:auto_save = 1  
  au FileType sh let b:auto_save = 1  
  au FileType dockerfile let b:auto_save = 1  
  au FileType javascript let b:auto_save = 1  
  au FileType vue let b:auto_save = 1  
  au FileType vim let b:auto_save = 1
  au FileType rmd let b:auto_save = 1
  au FileType tex let b:auto_save = 1
augroup END
" 
" }}}

" vim-commentary "{{{
nnoremap <Bs> :Commentary<CR>
autocmd FileType apache setlocal commentstring=#\ %s
autocmd BufNewFile,BufRead *.Xresources set filetype=xdefaults
autocmd FileType xdefaults setlocal commentstring=!\ %s
" }}}

" Vim Wiki {{{
autocmd BufRead,BufNewFile *.wiki set filetype=vimwik
let g:vimwiki_ext2syntax = {'.Rmd': 'markdown', '.rmd': 'markdown','.md': 'markdown', '.markdown': 'markdown', '.mdown': 'markdown'}
let g:vimwiki_list = [{'path': '~/code-home/VimWiki', 'syntax': 'markdown', 'ext': '.md'}]

let g:vim_markdown_math = 1
let g:vim_markdown_json_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_new_list_item_indent = 2


" }}}

" Vim Jedi {{{
" disable autocompletion, cause we use deoplete for completion
let g:jedi#completions_enabled = 1

" open the go-to function in split, not another buffer
let g:jedi#use_splits_not_buffers = "right"
" }}}

"
" Vim Highlight Yank {{{
hi HighlightedyankRegion cterm=reverse gui=reverse
" set highlight duration time to 1000 ms, i.e., 1 second
let g:highlightedyank_highlight_duration = 1000

" }}}

" Pathogen load
filetype off

" call pathogen#infect()
" call pathogen#helptags()

filetype plugin indent on
syntax on

"  Jupyter-vim {{{
if has('nvim')
    let g:python3_host_prog = '/usr/bin/python'
else
    set pyxversion=3
endif

let g:jupyter_mapkeys = 0
" Run current file
nnoremap <buffer> <silent> <localleader>R :JupyterRunFile<CR>
nnoremap <buffer> <silent> <localleader>I :JupyterImportThisFile<CR>

" Change to directory of current file
nnoremap <buffer> <silent> <localleader>d :JupyterCd %:p:h<CR>

" Send a selection of lines
nnoremap <buffer> <silent> <localleader>X :JupyterSendCell<CR>
nnoremap <buffer> <silent> <localleader>E :JupyterSendRange<CR>
nmap     <buffer> <silent> <localleader>e <Plug>JupyterRunTextObj
vmap     <buffer> <silent> <localleader>e <Plug>JupyterRunVisual

nnoremap <buffer> <silent> <localleader>U :JupyterUpdateShell<CR>

" Debugging maps
nnoremap <buffer> <silent> <localleader>b :PythonSetBreak<CR>
" }}}

" Vim Notebook {{{
let g:notebook_highlight = 1

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

" Python Mode {{{
let g:pymode_python = 'python'
" ignore line too long warnings
let g:pymode_lint_ignore = ["E501", "W",]
let g:pymode_virtualenv = 1
let g:pymode_pymode_rope_completeion = 1
"
" }}}

" Suda.vim {{{
let g:suda#prefix = 'suda://'
" multiple protocols can be defined too
let g:suda#prefix = ['suda://', 'sudo://', '_://']
let g:suda_smart_edit = 1
" }}}


" Animation things {{{
let g:animate#duration = 300.0
let g:animate#easing_func = 'animate#ease_out_cubic'

" }}}
" Vim Latex Live Preview {{{
let g:livepreview_previewer = 'zathura'
let g:livepreview_cursorhold_recompile = 1
let g:vimtex_compiler_progname = 'nvr'

" }}}


" Deoplete {{{
" Use deoplete.
let g:deoplete#enable_at_startup = 1
" Use smartcase.
call deoplete#custom#option('smart_case', v:true)
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | pclose | endif
" inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"

" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function() abort
  return deoplete#close_popup() . "\<CR>"
endfunction

" https://gregjs.com/vim/2016/neovim-deoplete-jspc-ultisnips-and-tern-a-config-for-kickass-autocompletion/

" so deoplete plays nice with other autocomplete things
let g:deoplete#omni#functions = {}
let g:deoplete#omni#functions.javascript = [
  \ 'tern#Complete',
  \ 'jspc#omni'
\]
set completeopt=longest,menuone,preview
let g:deoplete#sources = {}
let g:deoplete#sources['javascript.jsx'] = ['file', 'ultisnips', 'ternjs']
let g:tern#command = ['tern']
let g:tern#arguments = ['--persistent']
call deoplete#custom#option('num_processes', 1)

autocmd FileType javascript let g:SuperTabDefaultCompletionType = "<c-x><c-o>"
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" autocmd BufWritePre *.py execute ':Black'
" }}}
"



" any jump

" Normal mode: Jump to definition under cursore
nnoremap <leader>j :AnyJump<CR>

" Visual mode: jump to selected text in visual mode
xnoremap <leader>j :AnyJumpVisual<CR>

" Normal mode: open previous opened file (after jump)
nnoremap <leader>ab :AnyJumpBack<CR>

" Normal mode: open last closed search window again
nnoremap <leader>al :AnyJumpLastResults<CR>


" vim-esearch
" Start esearch prompt autofilled with one of g:esearch.use initial patterns
call esearch#map('<leader>ff', 'esearch')
" Start esearch autofilled with a word under the cursor
call esearch#map('<leader>fw', 'esearch-word-under-cursor')

call esearch#out#win#map('t',       'tab')
call esearch#out#win#map('i',       'split')
call esearch#out#win#map('s',       'vsplit')
call esearch#out#win#map('<Enter>', 'open')
call esearch#out#win#map('o',       'open')

"    Open silently (keep focus on the results window)
call esearch#out#win#map('T', 'tab-silent')
call esearch#out#win#map('I', 'split-silent')
call esearch#out#win#map('S', 'vsplit-silent')

"    Move cursor with snapping
call esearch#out#win#map('<C-n>', 'next')
call esearch#out#win#map('<C-j>', 'next-file')
call esearch#out#win#map('<C-p>', 'prev')
call esearch#out#win#map('<C-k>', 'prev-file')

call esearch#cmdline#map('<C-o><C-r>', 'toggle-regex')
call esearch#cmdline#map('<C-o><C-s>', 'toggle-case')
call esearch#cmdline#map('<C-o><C-w>', 'toggle-word')
call esearch#cmdline#map('<C-o><C-h>', 'cmdline-help')

hi ESearchMatch ctermfg=black ctermbg=white guifg=#000000 guibg=#E6E6FA

