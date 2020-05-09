" --------------------------------------------------- Load Plugins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')
Plug 'lambdalisue/suda.vim' " runs `sudo` when needed.. no need to sudo vim blah
Plug 'vim-pandoc/vim-rmarkdown'
Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'vimwiki/vimwiki' 
Plug 'scrooloose/nerdtree' " file system nav
Plug 'tpope/vim-commentary' " easy commenting of code
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes' 
Plug 'kien/rainbow_parentheses.vim' " easily spot missing }
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
Plug 'JuliaLang/julia-vim'
Plug 'junegunn/vim-easy-align' 
Plug 'camspiers/animate.vim' " moves panes in a pretty way
Plug 'camspiers/lens.vim' " auto-magically resizes vim panes for you
Plug 'lervag/vimtex' " for writing latex
Plug 'xuhdev/vim-latex-live-preview', { 'for': 'tex' } " for writing latex
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'pechorin/any-jump.vim' " pops up a window of all the times code is referenced
Plug 'eugen0329/vim-esearch'
Plug 'francoiscabrol/ranger.vim' " ranger in vima
Plug 'joshdick/onedark.vim' " new favorite theme
Plug 'sheerun/vim-polyglot'
Plug 'neoclide/coc.nvim', {'branch': 'release'} " intelisense auto-complete
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'AndrewRadev/tagalong.vim' " auto-magically change html tags
Plug 'tpope/vim-surround' " easily put quotes and other things around stuff
call plug#end()

