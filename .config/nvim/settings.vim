set runtimepath^=~/.config/nvim runtimepath+=~/.config/nvim/after
set backupdir=~/.config/nvim/backups
set directory=~/.config/nvim/swaps
set undodir=~/.config/nvim/undo
let &packpath=&runtimepath
" set nocompatible
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
