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
au BufEnter * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'
" nnoremap <silent> <CR> :exe 'silent! normal! '.((foldclosed('.')>0)? 'zMzx' : 'za')<CR>
noremap <silent> <CR> :call SingleUnrollMe()<CR>
noremap <F5> :call UnrolMe()<CR>
imap <C-h> <C-w>h
imap <C-j> <C-w>j
imap <C-k> <C-w>k
imap <C-l> <C-w>l

"Zoom" a split window into a tab and/or close it {{{
nmap <Leader>zo :tabnew %<CR>
nmap <Leader>zc :tabclose<CR>
"}}}

" Better window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
" Terminal window navigation
tnoremap <C-h> <C-\><C-N><C-w>h
tnoremap <C-j> <C-\><C-N><C-w>j
tnoremap <C-k> <C-\><C-N><C-w>k
tnoremap <C-l> <C-\><C-N><C-w>l
inoremap <C-h> <C-\><C-N><C-w>h
inoremap <C-j> <C-\><C-N><C-w>j
inoremap <C-k> <C-\><C-N><C-w>k
inoremap <C-l> <C-\><C-N><C-w>l
tnoremap <Esc> <C-\><C-n>
