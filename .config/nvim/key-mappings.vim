" vim:fdm=marker
" ^^^^^^^^^^^^^ ---- tells vim to treat comments as folds

" Map Esc to Caps Lock {{{
au VimEnter * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'
" au VimLeave * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Caps_Lock'
" }}}

" Faster save and exit (Ctrl-s, Ctrl-q, Ctrl-d) {{{
inoremap <C-s> <esc>:w<cr>                 " save files
nnoremap <C-s> :w<cr>
" inoremap <C-d> <esc>:wq!<cr>               " save and exit
" noremap <C-d> :wq!<cr>
noremap <C-q> <esc>:q<cr>               " quit discarding changes
noremap <C-q> :q<cr>
" }}}

" Move between Closed Folds {{{
nnoremap <silent> <S-j> :call NextClosedFold('j')<cr>
nnoremap <silent> <S-k> :call NextClosedFold('k')<cr>
function! NextClosedFold(dir)
    let cmd = 'norm!z' . a:dir
    let view = winsaveview()
    let [l0, l, open] = [0, view.lnum, 1]
    while l != l0 && open
        exe cmd
        let [l0, l] = [l, line('.')]
        let open = foldclosed(l) < 0
    endwhile
    if open
        call winrestview(view)
    endif
endfunction
" }}}

" Yank from cursor to end of line {{{
nnoremap Y y$
" }}}

" Insert New Line {{{
map <leader><CR> o<ESC>
" }}}

" Toggle Folds (<Space>) {{{
nnoremap <silent> <CR> :exe 'silent! normal! '.((foldclosed('.')>0)? 'zMzx' : 'zc')<CR>

noremap <F5> :call UnrolMe()<CR>

let $unrol=0
function UnrolMe()
if $unrol==0
    :exe "normal zR"
    let $unrol=1
else
    :exe "normal zM"
    let $unrol=0
endif
endfunction
" }}}

" Strip trailing whitespace (,ss) {{{
function! StripWhitespace () " {{{
  let save_cursor = getpos(".")
  let old_query = getreg('/')
  :%s/\s\+$//e
  call setpos('.', save_cursor)
  call setreg('/', old_query)
endfunction " }}}
noremap <leader>ss :call StripWhitespace ()<CR>
" }}}

" Clear last search (,qs) {{{
map <silent> <leader>cs <Esc>:noh<CR>
" map <silent> <leader>qs <Esc>:let @/ = ""<CR>
" }}}

" Window Pane Resizing {{{
noremap + :resize +5 <CR>
noremap - :resize -5 <CR>
noremap < :vertical:resize -5 <CR>
noremap > :vertical:resize +5 <CR>
"}}}
"
" "Zoom" a split window into a tab and/or close it {{{
nmap <Leader>zo :tabnew %<CR>
nmap <Leader>zc :tabclose<CR>
"}}}

" Tab lines over {{{
vnoremap <Tab> >
vnoremap <S-Tab> <
" }}}


" Speed up viewport scrolling {{{
" Ctrl-j Scroll down 3 rows at a time
nnoremap <C-j> 3<C-e>
" Ctrl-k Scroll up 3 rows at a time
nnoremap <C-k> 3<C-y>
" }}}
"
if has('nvim')
    cnoremap w!! execute 'silent! write !SUDO_ASKPASS=`which ssh-askpass` sudo tee % >/dev/null' <bar> edit!
else
    command! -nargs=0 Sw w !sudo tee % > /dev/null
endif

" toggle unprintable characters in all modes {{{
set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
noremap <F4> :set list!<CR>
inoremap <F4> <C-o>:set list!<CR>
cnoremap <F4> <C-c>:set list!<CR>
"}}}

