let g:startify_lists = [
          \ { 'type': 'files',     'header': ['   Files']            },
          \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
          \ { 'type': 'sessions',  'header': ['   Sessions']       },
          \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
          \ ]

let g:startify_bookmarks = [
            \ { 'd': '~/.config/qtile/config.py' },
            \ { 'i': '~/.config/nvim/init.vim' },
            \ { 'p': '~/.config/nvim/load_plugins.vim' },
            \ { 'K': '~/.config/nvim/key-mappings.vim' },
            \ { 'o': '~/.config/nvim/coc-settings.json' },
            \ { 'z': '~/.zshrc' },
            \ '~/code-home',
            \ '~/Pictures',
            \ '~/Documents',
            \ { 'P': '~/.config/nvim/plug-config' }
            \ ]

let g:startify_session_autoload = 1

let g:startify_session_delete_buffers = 1
let g:startify_change_to_vcs_root = 1
let g:startify_fortune_use_unicode = 1
let g:startify_session_persistence = 1
let g:startify_enable_special = 0

let g:startify_custom_header = [
        \ '████████╗██╗  ██╗███████╗     ██████╗ █████╗ ███╗   ███╗██████╗  ██████╗ ██████╗  ██████╗ ██╗   ██╗███╗   ██╗██████╗', 
        \ '╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔══██╗████╗ ████║██╔══██╗██╔════╝ ██╔══██╗██╔═══██╗██║   ██║████╗  ██║██╔══██╗',
        \ '   ██║   ███████║█████╗      ██║     ███████║██╔████╔██║██████╔╝██║  ███╗██████╔╝██║   ██║██║   ██║██╔██╗ ██║██║  ██║',
        \ '   ██║   ██╔══██║██╔══╝      ██║     ██╔══██║██║╚██╔╝██║██╔═══╝ ██║   ██║██╔══██╗██║   ██║██║   ██║██║╚██╗██║██║  ██║',
        \ '   ██║   ██║  ██║███████╗    ╚██████╗██║  ██║██║ ╚═╝ ██║██║     ╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║ ╚████║██████╔╝',
        \ '   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═════╝ '
        \]                                                                                                                     

" map <c-h> :Startify<CR>
