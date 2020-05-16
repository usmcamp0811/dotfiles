set runtimepath^=~/.config/nvim runtimepath+=~/.config/nvim/after
set backupdir=~/.config/nvim/backups
set directory=~/.config/nvim/swaps
set undodir=~/.config/nvim/undo
let &packpath=&runtimepath
set nocompatible
set t_Co=256
set termguicolors
set clipboard+=unnamedplus
set autoindent " Copy indent from last line when starting new line
set cursorline " Highlight current line
set foldenable " enable folding
set expandtab
set diffopt=filler " add vertical spaces to keep right and left aligned
set diffopt+=iwhite " Ignore whitespace changes
set softtabstop=4 " Tab key returns 4 spaces
set shiftwidth=4 " Set # spaces for indention
set nowrap " Don't wrap lines
set mouse=a " Enable mouse in all modes
set magic " Enable extended regex commands
set nojoinspaces " Only insert single space after a '.', '?' and '!' with a join command
set noshowmode " Going to use airline.vim to handle this for us
set nostartofline " Don't reset cursor to the start of the line when moving around
set ruler " Show current position
set nu " enable line numbers
set shell=/bin/bash
set splitbelow " New windows go below
set splitright " New windows go right
set title " Show the filename in the window titlebar
set undofile " Persistent Undo
set wildmenu " Hitting TAB in command mode will show possible completion above command line
set wrapscan " Searches wrap around end of file
set encoding=utf-8 nobomb
set guioptions+=a " copy on select... requires gvim
set wildchar=<TAB> " Character for CLI expansion (TAB-completion)
set shortmess=atI " Don't show the intro message when starting vim
set showtabline=2 " Always show tab bar
set sidescrolloff=3 " Start scrolling three columns before vertical border of window
set smartcase " Ignore 'ignorecase' if search patter contains uppercase characters
set smarttab " At start of line, <Tab> inserts shiftwidth spaces, <Bs> deletes shiftwidth spaces
set scrolloff=3 " Start scrolling three lines before horizontal border of window
set lazyredraw " Don't redraw when we don't have to
set laststatus=2 " Always show status line
set wildignore+=.DS_Store
set wildignore+=*.jpg,*.jpeg,*.gif,*.png,*.gif,*.psd,*.o,*.obj,*.min.js
set wildignore+=*/bower_components/*,*/node_modules/*
set wildignore+=*/smarty/*,*/vendor/*,*/.git/*,*/.hg/*,*/.svn/*,*/.sass-cache/*,*/log/*,*/tmp/*,*/build/*,*/ckeditor/*,*/doc/*,*/source_maps/*,*/dist/*
set wildmode=longest,list,full
set spell " turns on spell check
set relativenumber " Use relative line numbers. Current line is still in status bar.
au BufReadPost,BufNewFile * set relativenumber
filetype plugin on
syntax enable
set timeout timeoutlen=3000 ttimeoutlen=10 " speed up mode switching
" Enable Text Folding {{{
if has('folding')
    if has('windows')
        set fillchars=vert:┃
        set fillchars+=fold:·
    endif
    set foldenable " turn it on
    set foldcolumn=0 "Column to show folds
    set foldlevel=1 "Close all folds by default
    set foldmethod=syntax " Syntax are used to specify folds
endif
set foldminlines=0 " Allow folding single lines
set foldnestmax =10 " Set max fold nesting level
" }}}

let g:mapleader = "\<Space>"
let gmaplocalkeader = '\'
inoremap <C-s> <esc>:w<cr>                        " save files
nnoremap <C-s> :w<cr>
" inoremap <C-d> <esc>:wq!<cr>                      " save and exit
" noremap <C-d> :wq!<cr>
noremap <C-q> <esc>:q<cr>                         " quit discarding changes
noremap <C-q> :q<cr>
nnoremap Y y$                                     " Yank from cursor to end of line
nnoremap <leader><CR> o<ESC>                      " Insert New Line
map <silent> <localleader>cs <Esc>:noh<CR>        " Clear last search (,qs)
vnoremap <Tab> >                                  " Tab lines right   TODO: COC breaks this
vnoremap <S-Tab> <                                " Tab lines left
noremap + :resize +5 <CR>                         " Window Pane Resizing Horizontal
noremap - :resize -5 <CR>
noremap < :vertical:resize -5 <CR>                " Window Pane Resizing Vertical
noremap > :vertical:resize +5 <CR>
nnoremap <C-j> 3<C-e>                             " Ctrl-j Scroll down 3 rows at a time
nnoremap <C-k> 3<C-y>                             " Ctrl-k Scroll up 3 rows at a time
set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
noremap <F8> :set list!<CR>                       " toggle unprintable characters in all modes
inoremap <F8> <C-o>:set list!<CR>                 " toggle unprintable characters in all modes
cnoremap <F8> <C-c>:set list!<CR>                 " toggle unprintable characters in all modes
xnoremap <silent> K :call visual#move_up()<CR>    " move blocks of text visually UP.. https://www.youtube.com/watch?v=X5IAdaN6IwM
xnoremap <silent> J :call visual#move_down()<CR>  " move blocks of text visually DOWN..
map <leader>. :source ~/.config/nvim/init.vim<CR> " Re-source init.vim
nnoremap <C-Up> <C-a>                             " re-map increment UP numbers to the arrows
nnoremap <C-Down> <C-x>                           " re-map increment DOWN numbers to the arrows
"
" nnoremap <silent> <CR> :exe 'silent! normal! '.((foldclosed('.')>0)? 'zMzx' : 'za')<CR>
noremap <silent> <CR> :call SingleUnrollMe()<CR>
noremap <F5> :call UnrolMe()<CR>

function SingleUnrollMe()
if $sunrol==0
    :exe "normal zc"
    let $sunrol=1
else
    :exe "normal zo"
    let $sunrol=0
endif
endfunction

let $unrol=0
function UnrolMe()
if $unrol==0
    :exe "normal zR"
    let $unrol=1
else
    :exe "normal zM"
    let $unrol=0
endif
endfunction
" }}}


"Zoom" a split window into a tab and/or close it {{{
nmap <Leader>zo :tabnew %<CR>
nmap <Leader>zc :tabclose<CR>
"}}}
" useful markdown bindings {{{
nnoremap <localleader>1 m`yypVr=``
nnoremap <localleader>2 m`yypVr-``
nnoremap <localleader>3 m`^i### <esc>``4l
nnoremap <localleader>4 m`^i#### <esc>``5l
nnoremap <localleader>5 m`^i##### <esc>``6l
"}}}

" Restore Cursor Position {{{
augroup restore_cursor
  autocmd!
  autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif
augroup END
" }}}

" Triger `autoread` when files changes on disk {{{
" https://unix.stackexchange.com/questions/149209/refresh-changed-content-of-file-opened-in-vim/383044#383044
" https://vi.stackexchange.com/questions/13692/prevent-focusgained-autocmd-running-in-command-line-editing-mode
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI *
            \ if mode() !~ '\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif

" Notification after file change
" https://vi.stackexchange.com/questions/13091/autocmd-event-for-autoread
autocmd FileChangedShellPost *
            \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None
autocmd VimEnter * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape' " Map Esc to Caps Lock 

source ~/.config/nvim/load_plugins.vim
source ~/.config/nvim/plug-config/onedark.vim
