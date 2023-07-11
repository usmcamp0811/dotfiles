" save files
inoremap <C-s> <esc>:w<cr>
nnoremap <C-s> :w<cr>
" inoremap <C-d> <esc>:wq!<cr>                      " save and exit
" noremap <C-d> :wq!<cr>
" quit discarding changes
noremap <C-q> <esc>:q<cr>                         
noremap <C-q> :q<cr>
" Yank from cursor to end of line
nnoremap Y y$                                     
" Insert New Line
" nnoremap <leader><CR> o<ESC>
" Clear last search (,qs)
map <silent> <localleader>cs <Esc>:noh<CR>        
" Tab lines right   TODO: COC breaks this
vnoremap <Tab> >
" Tab lines left
vnoremap <S-Tab> <
" Window Pane Resizing Horizontal
noremap + :resize +5 <CR>
noremap - :resize -5 <CR>
" Window Pane Resizing Vertical
" noremap < :vertical:resize -5 <CR>
" noremap > :vertical:resize +5 <CR>
" Ctrl-j Scroll down 3 rows at a time
nnoremap <C-j> 3<C-e>                 
" Ctrl-k Scroll up 3 rows at a time
nnoremap <C-k> 3<C-y>

set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
" toggle unprintable characters in all modes
noremap <F8> :set list!<CR>
" toggle unprintable characters in all modes
inoremap <F8> <C-o>:set list!<CR>
" toggle unprintable characters in all modes
cnoremap <F8> <C-c>:set list!<CR>
" move blocks of text visually UP.. https://www.youtube.com/watch?v=X6IAdaN6IwM
" xnoremap <silent> K :call visual#move_up()<CR>
" move blocks of text visually DOWN..
" xnoremap <silent> J :call visual#move_down()<CR>
" Re-source init.vim
map <leader>. :source ~/.config/nvim/init.vim<CR>
" re-map increment UP numbers to the arrows
nnoremap <C-Up> <C-a>       
" re-map increment DOWN numbers to the arrows
nnoremap <C-Down> <C-x>
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


map [[ :silent! eval search('```', 'b')<CR>w99[{

map ][ :silent! eval search('```')<CR>b99]}

map ]] j0[[%:silent! eval search('`')<CR>

map [] k$][%:silent! eval search('`', 'b')<CR>

" toggle fold
nnoremap <s-tab> za
