highlight CodiVirtualText guifg=cyan
let g:codi#virtual_text_prefix = "❯ "

" let g:codi#aliases = {
                   " \ 'javascript.jsx': 'javascript',
                   " \ }
let g:codi#interpreters = {
                   \ 'python': {
                   \ 'bin': 'python',
                   \ 'prompt': '^\(>>>\|\.\.\.\) ',
                   \ },
                   \ 'Julia': {
                   \ 'bin': ['julia', '-qi', '--color=no', '--history-file=no', '--startup-file=no'],
                   \ 'prompt': '^\(julia>\) '
                   \ }
                   \ }


let g:codi#log= '/home/mcamp/code-home/codi_log'
let g:codi#raw= 1
