set runtimepath^=~/.config/nvim runtimepath+=~/.config/nvim/after
let &packpath=&runtimepath

" Make vim modern {{{
set nocompatible
" }}}

" Syntax highlighting {{{
set t_Co=256

" give our selves some more colors
" TODO: make check that our terminal supports this
set termguicolors
set clipboard+=unnamedplus
syntax enable
" colorscheme cobalt
" colorscheme solarized8_flat
colorscheme night-owl
" colorscheme one
" colorscheme onedark

let g:lightline = { 'colorscheme': 'nightowl' }

hi SpellBad    ctermfg=9      ctermbg=16     cterm=underline   
" }}}

" Mapleader {{{
let mapleader=" "
" }}}

" Set Vim Directories {{{
set backupdir=~/.config/nvim/backups
set directory=~/.config/nvim/swaps
set undodir=~/.config/nvim/undo
" }}}

source ~/.config/nvim/general.vim
source ~/.config/nvim/load_plugins.vim
source ~/.config/nvim/config_plugins.vim
source ~/.config/nvim/key-mappings.vim
