let $sunrol=0
function SingleUnrollMe()
if $sunrol==0
    :exe "normal zc"
    let $sunrol=1
else
    :exe "normal zo"
    let $sunrol=0
endif
endfunction

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

" https://www.reddit.com/r/vim/comments/fob3sg/different_background_color_for_markdown_code/
" Markdown Code Block Background {{{
setl signcolumn=no

hi markdownCodeBlockBG ctermbg=black guibg=#21242b

sign define codeblock linehl=markdownCodeBlockBG

function! MarkdownBlocks()
    let l:continue = 0
    execute "sign unplace * file=".expand("%")

    " iterate through each line in the buffer
    for l:lnum in range(1, len(getline(1, "$")))
        " detect the start fo a code block
        if getline(l:lnum) =~ "^```.*$" || l:continue
            " continue placing signs, until the block stops
            let l:continue = 1
            " place sign
            execute "sign place ".l:lnum." line=".l:lnum." name=codeblock file=".expand("%")
            " stop placing signs
            if getline(l:lnum) =~ "^```$"
                let l:continue = 0
            endif
        endif
    endfor
endfunction

function! LightBlocks()
    let l:continue = 0
    execute "sign unplace * file=".expand("%")

    " iterate through each line in the buffer
    for l:lnum in range(1, len(getline(1, "$")))
        " detect the start fo a code block
        if getline(l:lnum) =~ "^#\s/{/{/{.*$" || l:continue
            " continue placing signs, until the block stops
            let l:continue = 1
            " place sign
            execute "sign place ".l:lnum." line=".l:lnum." name=codeblock file=".expand("%")
            " stop placing signs
            if getline(l:lnum) =~ "^#\s/}/}/}$"
                let l:continue = 0
            endif
        endif
    endfor
endfunction

function! PercentBlocks()
    let l:continue = 0
    execute "sign unplace * file=".expand("%")

    " iterate through each line in the buffer
    for l:lnum in range(1, len(getline(1, "$")))
        " detect the start fo a code block
        if getline(l:lnum) =~ "^#\s%%$" || l:continue
            " continue placing signs, until the block stops
            let l:continue = 1
            " place sign
            execute "sign place ".l:lnum." line=".l:lnum." name=codeblock file=".expand("%")
            " stop placing signs
            if getline(l:lnum) =~ "^#\s%%$"
                let l:continue = 0
            endif
        endif
    endfor
endfunction

let g:markdown_github_languages = ['python', 'julia', 'bash', 'zsh', 'clojure']
" }}}
