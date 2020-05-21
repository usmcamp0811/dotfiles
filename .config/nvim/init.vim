let g:mapleader = "\<Space>"
let gmaplocalkeader = '\'

" --------------------------------------------------- Load Vim Settings -----------------------------------------------------------------
source ~/.config/nvim/settings.vim
source ~/.config/nvim/mappings.vim
source ~/.config/nvim/functions.vim
source ~/.config/nvim/autocmds.vim

" --------------------------------------------------- Load Plug-ins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')
Plug 'norcalli/nvim-colorizer.lua' " real-time colorizer
Plug 'junegunn/rainbow_parentheses.vim' " easily spot missing }
Plug 'lambdalisue/suda.vim' " runs `sudo` when needed.. no need to sudo vim blah
" Plug 'vim-pandoc/vim-rmarkdown' "rmakrdown support for vim
" Plug 'vim-pandoc/vim-pandoc'
" Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'vimwiki/vimwiki' , { 'branch': 'dev' }" a wiki for managing knowledge 
Plug 'tpope/vim-commentary' " easy commenting of code
Plug 'vim-airline/vim-airline-themes' 
Plug 'vim-airline/vim-airline'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'mbbill/undotree' " don't use it as much as I should but its neat
Plug 'sirver/UltiSnips'
Plug 'honza/vim-snippets'
Plug 'ctrlpvim/ctrlp.vim'
" Plug 'FelikZ/ctrlp-py-matcher'
Plug 'suy/vim-context-commentstring' " figures out what comment string to use
Plug 'godlygeek/tabular' " makes markdown tables
Plug '907th/vim-auto-save' " does what it says
Plug 'junegunn/vim-easy-align' 
Plug 'camspiers/animate.vim' " moves panes in a pretty way
Plug 'camspiers/lens.vim' " auto-magically resizes vim panes for you
Plug 'lervag/vimtex' " for writing latex
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'pechorin/any-jump.vim' " pops up a window of all the times code is referenced
Plug 'eugen0329/vim-esearch'
Plug 'kevinhwang91/rnvimr', {'do': 'make sync'} " ranger in vima
Plug 'joshdick/onedark.vim' " new favorite theme
Plug 'sheerun/vim-polyglot' " multiple programing language support
Plug 'neoclide/coc.nvim', {'branch': 'release'} " intelisense auto-complete
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'AndrewRadev/tagalong.vim' " auto-magically change html tags
Plug 'tpope/vim-surround' " easily put quotes and other things around stuff
Plug 'unblevable/quick-scope' " easier horizontal jumping
Plug 'justinmk/vim-sneak' " better vertical jumping
Plug 'liuchengxu/vim-which-key' " useful tool to help remember what got mapped where.. also kind of an alternative way to map keys
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' " super useful search files
Plug 'airblade/vim-rooter' " puts you in the root of the project
Plug 'mhinz/vim-startify' " a start page for vim when no file is opened
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' } " really good Go lang support for vim
Plug 'sedm0784/vim-you-autocorrect' " autocorrect for vim
Plug 'voldikss/vim-floaterm' " lets you make anything a floating window in vim
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/gv.vim' " part of git config
Plug 'tpope/vim-fugitive' " part of git config
Plug 'jpalardy/vim-slime' " allow vim to send julia / python commands to the repl
call plug#end()

" --------------------------------------------------- Load Plug-in Configurations -----------------------------------------------------------------
source $HOME/.config/nvim/plug-config/airline.vim
source $HOME/.config/nvim/plug-config/animate.vim
source $HOME/.config/nvim/plug-config/any-jump.vim
source $HOME/.config/nvim/plug-config/autosave.vim
source $HOME/.config/nvim/plug-config/coc.vim
source $HOME/.config/nvim/plug-config/easy-align.vim
source $HOME/.config/nvim/plug-config/fzf.vim
source $HOME/.config/nvim/plug-config/highlight-yank.vim
source $HOME/.config/nvim/plug-config/julia.vim
" source $HOME/.config/nvim/plug-config/jupyter-vim.vim
source $HOME/.config/nvim/plug-config/lens.vim
" source $HOME/.config/nvim/plug-config/notebook.vim
source $HOME/.config/nvim/plug-config/quickscope.vim
source $HOME/.config/nvim/plug-config/rainbow-parenthesis.vim
source $HOME/.config/nvim/plug-config/ranger.vim
source $HOME/.config/nvim/plug-config/sneak.vim
source $HOME/.config/nvim/plug-config/suda.vim
source $HOME/.config/nvim/plug-config/tagalong.vim
source $HOME/.config/nvim/plug-config/ultisnips.vim
source $HOME/.config/nvim/plug-config/undotree.vim
source $HOME/.config/nvim/plug-config/vim-commentary.vim
source $HOME/.config/nvim/plug-config/vim-esearch.vim
source $HOME/.config/nvim/plug-config/vim-vue.vim
source $HOME/.config/nvim/plug-config/vim-which-key.vim
source $HOME/.config/nvim/plug-config/vimwiki.vim
source $HOME/.config/nvim/plug-config/vim-go.vim 
source $HOME/.config/nvim/plug-config/startify.vim 
source $HOME/.config/nvim/plug-config/floaterm.vim 
source $HOME/.config/nvim/plug-config/vim-you-autocorrect.vim 
source $HOME/.config/nvim/plug-config/slime.vim 
source $HOME/.config/nvim/plug-config/csv.vim 
source $HOME/.config/nvim/plug-config/onedark.vim 
lua require'plug-colorizer'

