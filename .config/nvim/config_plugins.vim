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

" let g:airline_theme='cobalt2' " <theme> is a valid theme name
" }}}

" lens {{{
let g:lens#disabled_filetypes = ['nerdtree', 'fzf']
let g:lens#animate = 0
" }}}

" Using Emojis as Git Gutter symbols {{{

" if emoji#available()
"     let g:gitgutter_sign_added = emoji#for('small_blue_diamond')
"     let g:gitgutter_sign_modified = emoji#for('small_orange_diamond')
"     let g:gitgutter_sign_removed = emoji#for('small_red_triangle')
"     let g:gitgutter_sign_modified_removed = emoji#for('collision')
" endif
" }}}

" undotree {{{
nnoremap <F5> :UndotreeToggle<cr>
" }}}

" UltiSnips {{{
" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
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
  au FileType vue let b:auto_save = 0
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
let g:vimwiki_list = [{'path': '~/vimwiki', 'syntax': 'markdown', 'ext': '.md'}]

let g:vim_markdown_math = 1
let g:vim_markdown_json_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_new_list_item_indent = 2


" }}}

" Vim Jedi {{{
" disable autocompletion, cause we use deoplete for completion
" let g:jedi#completions_enabled = 1

" open the go-to function in split, not another buffer
" let g:jedi#use_splits_not_buffers = "right"
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
" let g:pymode_python = 'python3'
" ignore line too long warnings
" let g:pymode_lint_ignore = ["E501", "W",]
" let g:pymode_virtualenv = 1
" let g:pymode_virtualenv_path='/home/mcamp/'
" let g:pymode_pymode_rope_completeion = 1
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


" any jump

" Normal mode: Jump to definition under cursore
nnoremap <leader>j :AnyJump<CR>

" Visual mode: jump to selected text in visual mode
xnoremap <leader>j :AnyJumpVisual<CR>

" Normal mode: open previous opened file (after jump)
nnoremap <leader>ab :AnyJumpBack<CR>

" Normal mode: open last closed search window again
nnoremap <leader>al :AnyJumpLastResults<CR>

" COC {{{
" TextEdit might fail if hidden is not set.
set hidden

" Some servers have issues with backup files, see #649.
set nobackup
set nowritebackup

" Give more space for displaying messages.
set cmdheight=2

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current
" position. Coc only does snippet and additional edit on confirm.
if exists('*complete_info')
  inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
else
  imap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
endif

" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder.
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying codeAction to the selected region.
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying codeAction to the current line.
nmap <leader>ac  <Plug>(coc-codeaction)
" Apply AutoFix to problem on the current line.
nmap <leader>qf  <Plug>(coc-fix-current)

" Introduce function text object
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

" Use <TAB> for selections ranges.
" NOTE: Requires 'textDocument/selectionRange' support from the language server.
" coc-tsserver, coc-python are the examples of servers that support it.
nmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <TAB> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocAction('format')

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support.
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline.
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Mappings using CoCList:
" Show all diagnostics.
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>
" }}}
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

" vim vue 
" let g:vim_vue_plugin_load_full_syntax = 2
let g:vue_pre_processors = 'detect_on_enter'

"
" range in vim
" let g:NERDTreeHijackNetrw = 0 // add this line if you use NERDTree
" let g:ranger_replace_netrw = 1 // open ranger when vim open a directory
let g:ranger_command_override = 'ranger --cmd "set show_hidden=true"'
silent! nmap <F2> :Ranger<CR>

" tagalong {{{
let g:tagalong_additional_filetypes = ['html', 'vue', 'ts']

" }}}
