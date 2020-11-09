let g:mapleader = "\<Space>"
let gmaplocalkeader = '\'

" --------------------------------------------------- Load Vim Settings -----------------------------------------------------------------
source ~/.config/nvim/settings.vim
source ~/.config/nvim/mappings.vim
source ~/.config/nvim/functions.vim 
source ~/.config/nvim/autocmds.vim



" this needs to be loaded before the plugins
" --------------------------------------------------- Load Plug-ins -----------------------------------------------------------------
call plug#begin('~/.config/nvim/plugged')
Plug 'norcalli/nvim-colorizer.lua' " real-time colorizer
Plug 'tpope/vim-surround' " easily put quotes and other things around stuff
Plug 'junegunn/rainbow_parentheses.vim' " easily spot missing }
Plug 'lambdalisue/suda.vim' " runs `sudo` when needed.. no need to sudo vim blah
" Plug 'vim-pandoc/vim-rmarkdown' "rmakrdown support for vim
Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'vimwiki/vimwiki' , { 'branch': 'dev' } " a wiki for managing knowledge 
Plug 'chmp/mdnav'
Plug 'tpope/vim-commentary' " easy commenting of code
Plug 'ryanoasis/vim-devicons'
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'chrisbra/csv.vim'
Plug 'JuliaEditorSupport/julia-vim'
" Plug 'plasticboy/vim-markdown'
" Plug 'sheerun/vim-polyglot' " currently seeing slowdowns with markdown stuff
" when this is installed
Plug 'mbbill/undotree' " don't use it as much as I should but its neat
Plug 'honza/vim-snippets'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'suy/vim-context-commentstring' " figures out what comment string to use
Plug 'godlygeek/tabular' " makes markdown tables
Plug '907th/vim-auto-save' " does what it says
Plug 'junegunn/vim-easy-align' 
Plug 'camspiers/animate.vim' " moves panes in a pretty way
Plug 'camspiers/lens.vim' " auto-magically resizes vim panes for you
Plug 'lervag/vimtex' " for writing latex
" Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'matthew-brett/vim-rst-sections'
Plug 'pechorin/any-jump.vim' " pops up a window of all the times code is referenced
Plug 'eugen0329/vim-esearch'
Plug 'kevinhwang91/rnvimr', {'do': 'make sync'} " ranger in vima
Plug 'neoclide/coc.nvim', {'branch': 'release'} " intelisense auto-complete
Plug 'AndrewRadev/tagalong.vim' " auto-magically change html tags
Plug 'unblevable/quick-scope' " easier horizontal jumping
Plug 'justinmk/vim-sneak' " better vertical jumping
Plug 'liuchengxu/vim-which-key' " useful tool to help remember what got mapped where.. also kind of an alternative way to map keys
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' " super useful search files
Plug 'airblade/vim-rooter' " puts you in the root of the project
Plug 'mhinz/vim-startify' " a start page for vim when no file is opened
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' } " really good Go lang support for vim
" Plug 'sedm0784/vim-you-autocorrect' " autocorrect for vim
Plug 'voldikss/vim-floaterm' " lets you make anything a floating window in vim
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/gv.vim' " part of git config
Plug 'tpope/vim-fugitive' " part of git config
Plug 'jpalardy/vim-slime' " allow vim to send julia / python commands to the repl
Plug 'hanschen/vim-ipython-cell', { 'for': ['python', 'julia', 'markdown.pandoc']} " note: I modified this and am waiting on a MR.. so don't update
Plug 'mroavi/vim-julia-cell', { 'for': ['julia']}
Plug 'ChristianChiarulli/codi.vim'
Plug 'Konfekt/FastFold'
Plug 'dhruvasagar/vim-table-mode'
" Themes
" Plug 'joshdick/onedark.vim' " new favorite theme
" Plug 'laggardkernel/vim-one'
" Plug 'sonph/onehalf', {'rtp': 'vim/'}
" Plug 'kristijanhusak/vim-hybrid-material'
" Plug 'jacoborus/tender.vim'
" Plug 'chriskempson/base16-vim'
Plug 'itchyny/lightline.vim'
Plug 'mengelbrecht/lightline-bufferline'
" Plug 'mrossinek/deuterium' "Jupyter inteface too much of a wip
" Plug 'dbridges/vim-markdown-runner' " puts code output into markdown
Plug 'kshenoy/vim-signature' " show marks in gutter
call plug#end()


" --------------------------------------------------- Load Plug-in Configurations -----------------------------------------------------------------
source $HOME/.config/nvim/plug-config/animate.vim
source $HOME/.config/nvim/plug-config/any-jump.vim
source $HOME/.config/nvim/plug-config/autosave.vim
source $HOME/.config/nvim/plug-config/coc.vim
source $HOME/.config/nvim/plug-config/easy-align.vim
source $HOME/.config/nvim/plug-config/fzf.vim
source $HOME/.config/nvim/plug-config/highlight-yank.vim
source $HOME/.config/nvim/plug-config/julia.vim
source $HOME/.config/nvim/plug-config/lens.vim
source $HOME/.config/nvim/plug-config/sneak.vim
source $HOME/.config/nvim/plug-config/quickscope.vim
source $HOME/.config/nvim/plug-config/rainbow-parenthesis.vim
source $HOME/.config/nvim/plug-config/ranger.vim
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
source $HOME/.config/nvim/plug-config/codi.vim 
source $HOME/.config/nvim/plug-config/csv.vim 
source $HOME/.config/nvim/plug-config/pandoc.vim 
" source $HOME/.config/nvim/plug-config/onedark.vim 
source $HOME/.config/nvim/plug-config/lightline.vim
source $HOME/.config/nvim/plug-config/markdown-runner.vim
lua require'plug-colorizer'

" Theme
syntax enable
colorscheme base16-onedark
" Fix background color of SFast
highlight CocWarnSign guibg=#20232a guifg=#fe7f2d 
highlight CocInfoSign guibg=#20232a guifg=#6f8d9e
highlight CocErrorSign guibg=#20232a guifg=#a01d26
highlight CocHintSign guibg=#20232a guifg=#009973
" highlight SingleColumn guibg=#20232a 
"
" let g:markdown_folding = 1
" set synmaxcol=500
"
function! s:isAtStartOfLine(mapping)
  let text_before_cursor = getline('.')[0 : col('.')-1]
  let mapping_pattern = '\V' . escape(a:mapping, '\')
  let comment_pattern = '\V' . escape(substitute(&l:commentstring, '%s.*$', '', ''), '\')
  return (text_before_cursor =~? '^' . ('\v(' . comment_pattern . '\v)?') . '\s*\v' . mapping_pattern . '\v$')
endfunction

inoreabbrev <expr> <bar><bar>
          \ <SID>isAtStartOfLine('\|\|') ?
          \ '<c-o>:TableModeEnable<cr><bar><space><bar><left><left>' : '<bar><bar>'
inoreabbrev <expr> __
          \ <SID>isAtStartOfLine('__') ?

noremap <expr> <F7> LaTeXtoUnicode#Toggle()
noremap! <expr> <F7> LaTeXtoUnicode#Toggle()   


let g:ipython_cell_regex = 1
let g:ipython_cell_tag = '```( [^[].*)?'
let g:julia_cell_delimit_cells_by = 'marks'
let g:ipython_language = "Julia"


nmap zuz <Plug>(FastFoldUpdate)
let g:fastfold_savehook = 1
let g:fastfold_fold_command_suffixes =  ['x','X','a','A','o','O','c','C']
let g:fastfold_fold_movement_commands = [']z', '[z', 'zj', 'zk']
