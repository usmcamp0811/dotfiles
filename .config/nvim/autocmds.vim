" Restore Cursor Position {{{
augroup restore_cursor
  autocmd!
  autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif
augroup END
" }}}
"

" Triger `autoread` when files changes on disk {{{
" https://unix.stackexchange.com/questions/149209/refresh-changed-content-of-file-opened-in-vim/383044#383044
" https://vi.stackexchange.com/questions/13692/prevent-focusgained-autocmd-running-in-command-line-editing-mode
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI *
            \ if mode() !~ '\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif

" Notification after file change
" https://vi.stackexchange.com/questions/13091/autocmd-event-for-autoread
autocmd FileChangedShellPost *
            \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None
autocmd VimEnter * silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape' " Map Esc to Caps Lock 

" Save manual folds automatically
autocmd BufWinLeave *.* mkview
autocmd BufWinEnter *.* silent loadview 

" set indent folds for python
autocmd! FileType python set foldmethod=indent

autocmd FileType julia let g:which_key_map['<CR>'] = [ ':JuliaCellExecuteCellJump', 'Execute Julia Code Cell' ]

" map J and K to jump to the previous and next cell header
autocmd FileType pandoc.markdown nnoremap K :IPythonCellPrevCell<CR>
autocmd FileType pandoc.markdown nnoremap J :IPythonCellNextCell<CR>

autocmd FileType julia nnoremap K :JuliaCellPrevCell<CR>
autocmd FileType julia nnoremap J :JuliaCellNextCell<CR>

autocmd FileType julia set foldmethod=syntax
