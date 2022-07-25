set autowrite " per vim-go tut auto make if you call :make 
map <C-n> :cnext<CR>
map <C-m> :cprevious<CR>
" nnoremap <leader>a :cclose<CR>
"
let g:go_fmt_command = "goimports"
let g:go_list_type = "quickfix"
let g:go_test_timeout = '10s'
let g:go_textobj_include_function_doc = 1 "motion 
let g:go_highlight_types = 1
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_operators = 1
autocmd FileType go nmap <leader>t  <Plug>(go-test)
" autocmd FileType go nmap <leader>b  <Plug>(go-build)
autocmd FileType go nmap <leader>r  <Plug>(go-run)

" run :GoBuild or :GoTestCompile based on the go file
function! s:build_go_files()
  let l:file = expand('%')
  if l:file =~# '^\f\+_test\.go$'
    call go#test#Test(0, 1)
  elseif l:file =~# '^\f\+\.go$'
    call go#cmd#Build(0)
  endif
endfunction

autocmd FileType go nmap <leader>b :<C-u>call <SID>build_go_files()<CR>
autocmd FileType go nmap <Leader>c <Plug>(go-coverage-toggle)

" o for gO
" let g:which_key_map.o = {
      " \ 'name' : 'Golang' ,
      " \ 'b' : ['<C-u>call <SID>build_go_files()<CR>'                        , 'build go files'],
      " \ 'c' : ['<Plug>(go-coverage-toggle)', 'go coverage'],
      " \ 't' : ['<Plug>(go-test)', 'go test'],
      " \ 'r' : ['<Plug>(go-run)', 'go run'],
      " \ }
