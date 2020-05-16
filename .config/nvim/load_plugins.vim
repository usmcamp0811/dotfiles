" --------------------------------------------------- Load Plugins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')
Plug 'norcalli/nvim-colorizer.lua' " real-time colorizer
Plug 'junegunn/rainbow_parentheses.vim' " easily spot missing }
Plug 'lambdalisue/suda.vim' " runs `sudo` when needed.. no need to sudo vim blah
Plug 'vim-pandoc/vim-rmarkdown'
Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'vimwiki/vimwiki' 
" Plug 'scrooloose/nerdtree' " file system nav
Plug 'tpope/vim-commentary' " easy commenting of code
" Plug 'tomtom/tcomment_vim'
Plug 'vim-airline/vim-airline-themes' 
Plug 'vim-airline/vim-airline'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'mbbill/undotree' " don't use it as much as I should but its neat
Plug 'sirver/UltiSnips'
Plug 'honza/vim-snippets'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'FelikZ/ctrlp-py-matcher'
Plug 'suy/vim-context-commentstring' " figures out what comment string to use
Plug 'godlygeek/tabular' " makes markdown tables
Plug '907th/vim-auto-save' " does what it says
Plug 'panozzaj/vim-autocorrect'
Plug 'jupyter-vim/jupyter-vim'
Plug 'baruchel/vim-notebook'
Plug 'junegunn/vim-easy-align' 
Plug 'camspiers/animate.vim' " moves panes in a pretty way
Plug 'camspiers/lens.vim' " auto-magically resizes vim panes for you
Plug 'lervag/vimtex' " for writing latex
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'pechorin/any-jump.vim' " pops up a window of all the times code is referenced
Plug 'eugen0329/vim-esearch'
Plug 'kevinhwang91/rnvimr', {'do': 'make sync'} " ranger in vima
Plug 'joshdick/onedark.vim' " new favorite theme
Plug 'sheerun/vim-polyglot'
Plug 'neoclide/coc.nvim', {'branch': 'release'} " intelisense auto-complete
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'AndrewRadev/tagalong.vim' " auto-magically change html tags
Plug 'tpope/vim-surround' " easily put quotes and other things around stuff
Plug 'unblevable/quick-scope' " easier horizontal jumping
Plug 'justinmk/vim-sneak' " better vertical jumping
Plug 'liuchengxu/vim-which-key'
" FZF
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' " super useful search files
Plug 'airblade/vim-rooter' " puts you in the root of the project
Plug 'szymonmaszke/vimpyter'
Plug 'mhinz/vim-startify'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'JuliaEditorSupport/julia-vim'
Plug 'sedm0784/vim-you-autocorrect'
Plug 'voldikss/vim-floaterm'
call plug#end()


" import plug-in configurations 
source $HOME/.config/nvim/plug-config/airline.vim
source $HOME/.config/nvim/plug-config/animate.vim
source $HOME/.config/nvim/plug-config/any-jump.vim
source $HOME/.config/nvim/plug-config/autosave.vim
source $HOME/.config/nvim/plug-config/coc.vim
source $HOME/.config/nvim/plug-config/easy-align.vim
source $HOME/.config/nvim/plug-config/fzf.vim
source $HOME/.config/nvim/plug-config/highlight-yank.vim
source $HOME/.config/nvim/plug-config/julia.vim
source $HOME/.config/nvim/plug-config/jupyter-vim.vim
source $HOME/.config/nvim/plug-config/lens.vim
source $HOME/.config/nvim/plug-config/notebook.vim
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
" source $HOME/.config/nvim/plug-config/vim-you-autocorrect.vim 
lua require'plug-colorizer'

