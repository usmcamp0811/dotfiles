
" --------------------------------------------------- Load Plugins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')

if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
  Plug 'lambdalisue/suda.vim'
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
Plug 'vim-pandoc/vim-rmarkdown'
Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
Plug 'vimwiki/vimwiki'
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'kien/rainbow_parentheses.vim'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'https://github.com/Townk/vim-autoclose.git'
Plug 'scrooloose/syntastic'
Plug 'ap/vim-css-color'
Plug 'mbbill/undotree'
Plug 'sirver/UltiSnips'
" Plug 'zchee/deoplete-jedi'
Plug 'deoplete-plugins/deoplete-jedi'
Plug 'davidhalter/jedi-vim'
Plug 'ternjs/tern_for_vim', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'carlitux/deoplete-ternjs', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'othree/jspc.vim', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'honza/vim-snippets'
Plug 'junegunn/vim-easy-align'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'FelikZ/ctrlp-py-matcher'
Plug 'posva/vim-vue'
Plug 'othree/html5.vim'
" Plug 'leafOfTree/vim-vue-plugin'
Plug 'tmhedberg/SimpylFold'
Plug 'junegunn/vim-emoji'
Plug 'godlygeek/tabular'
Plug 'tpope/vim-markdown'
Plug 'deoplete-plugins/deoplete-docker'
Plug 'deoplete-plugins/deoplete-dictionary'
Plug 'craigemery/vim-autotag'
" Plug 'rstacruz/sparkup'
Plug '907th/vim-auto-save'
Plug 'panozzaj/vim-autocorrect'
Plug 'jupyter-vim/jupyter-vim'
Plug 'machakann/vim-highlightedyank'
Plug 'baruchel/vim-notebook'
Plug 'JuliaLang/julia-vim'

Plug 'dikiaap/minimalist'
Plug 'haishanh/night-owl.vim'
Plug 'junegunn/vim-easy-align'

Plug 'camspiers/animate.vim'
Plug 'camspiers/lens.vim'

Plug 'lervag/vimtex'
" A Vim Plugin for Lively Previewing LaTeX PDF Output
Plug 'xuhdev/vim-latex-live-preview', { 'for': 'tex' }
Plug 'lervag/vimtex'
Plug 'pechorin/any-jump.vim'
Plug 'eugen0329/vim-esearch'

Plug 'francoiscabrol/ranger.vim'
Plug 'rbgrouleff/bclose.vim'
call plug#end()

