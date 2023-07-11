"Credit joshdick
"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (empty($TMUX))
  if (has("nvim"))
  "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif
syntax on
let g:onedark_hide_endofbuffer = 1
let g:onedark_termcolors = 256
let g:onedark_terminal_italics = 1
" let g:lightline = {
  " \ 'colorscheme': 'onedark',
  " \ }
" set background=dark " for the dark version
" set background=light " for the light version
" colorscheme one
if (has("autocmd"))
  augroup colorextend
    autocmd!
    " Make `Function`s bold in GUI mode
    autocmd ColorScheme * call onedark#extend_highlight("Function", { "gui": "bold" })
    " Override the `Statement` foreground color in 256-color mode
    autocmd ColorScheme * call onedark#extend_highlight("Statement", { "fg": { "cterm": 128 } })
    " Override the `Identifier` background color in GUI mode
    autocmd ColorScheme * call onedark#extend_highlight("Identifier", { "bg": { "gui": "#333333" } })
    " An attempt to modify the gutter color 
    autocmd ColorScheme * call onedark#extend_highlight("SignColumn", { "bg": { "gui": "#20232a" } })
    autocmd ColorScheme * call onedark#extend_highlight("LineNr", { "bg": { "gui": "#20232a" } })
  augroup END
endif
" let g:lightline = { 'colorscheme': 'nightowl' }

hi SpellBad    ctermfg=9      ctermbg=16     cterm=underline   

colorscheme onedark

" Fix background color of COC icons in the gutter
highlight CocWarnSign guibg=#20232a guifg=#fe7f2d 
highlight CocInfoSign guibg=#20232a guifg=#6f8d9e
highlight CocErrorSign guibg=#20232a guifg=#a01d26
highlight CocHintSign guibg=#20232a guifg=#009973

