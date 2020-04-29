
" --------------------------------------------------- Load Plugins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')

Plug 'lambdalisue/suda.vim'
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
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'scrooloose/syntastic'
Plug 'mbbill/undotree'
Plug 'sirver/UltiSnips'
" Plug 'pangloss/vim-javascript'
Plug 'honza/vim-snippets'
Plug 'junegunn/vim-easy-align'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'FelikZ/ctrlp-py-matcher'
Plug 'suy/vim-context-commentstring'
Plug 'tmhedberg/SimpylFold'
Plug 'junegunn/vim-emoji'
Plug 'godlygeek/tabular'
Plug 'craigemery/vim-autotag'
Plug '907th/vim-auto-save'
Plug 'panozzaj/vim-autocorrect'
Plug 'jupyter-vim/jupyter-vim'
Plug 'baruchel/vim-notebook'
Plug 'JuliaLang/julia-vim'
Plug 'junegunn/vim-easy-align'

Plug 'camspiers/animate.vim'
Plug 'camspiers/lens.vim'

Plug 'lervag/vimtex'
" A Vim Plugin for Lively Previewing LaTeX PDF Output
Plug 'xuhdev/vim-latex-live-preview', { 'for': 'tex' }
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'pechorin/any-jump.vim'
Plug 'eugen0329/vim-esearch'

Plug 'francoiscabrol/ranger.vim'
" Plug 'rbgrouleff/bclose.vim'
Plug 'joshdick/onedark.vim'
Plug 'sheerun/vim-polyglot'

Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()

