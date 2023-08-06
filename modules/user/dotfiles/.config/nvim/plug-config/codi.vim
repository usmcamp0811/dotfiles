function! s:pp_remove_esc(line)
  " Replace �[?2004l or �[?2004h with newline
  return substitute(a:line, '�[?2004l\|�[?2004h', '\n', '')
endfunction

highlight CodiVirtualText guifg=cyan
let g:codi#virtual_text_prefix = "❯ "

" let g:codi#aliases = {
                   " \ 'javascript.jsx': 'javascript',
                   " \ }
let g:codi#interpreters = {
                   \ 'python': {
                   \ 'bin': 'python',
                   \ 'prompt': '^\(>>>\|\.\.\.\) ',
                   \ 'preprocess': function('s:pp_remove_esc'),
                   \ },
                   \ 'Julia': {
                   \ 'bin': ['julia', '-qi', '--color=no', '--history-file=no', '--startup-file=no'],
                   \ 'prompt': '^\(julia>\) ',
                   \ 'preprocess': function('s:pp_remove_esc')
                   \ }
                   \ }


let g:codi#log= '/home/mcamp/code-home/codi_log'
let g:codi#raw= 1
