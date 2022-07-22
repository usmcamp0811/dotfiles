augroup pandoc_syntax
    au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
    au! BufNewFile,BufFilePre,BufRead *.jmd set filetype=markdown.pandoc syntax=julia
augroup END


" let g:pandoc#syntax#codeblocks#embeds#langs = ["json=javascript","javascript", "ruby","python","bash=sh", "julia"]
let g:pandoc#syntax#codeblocks#embeds#langs = ["python", "julia"]
" let g:pandoc#folding#mode = ['manual']
let g:pandoc#folding#fdc = 0

" Use signs to highlight code blocks
" Set signs on loading the file, leaving insert mode, and after writing it
augroup code_block_color
    au!
    au BufEnter *.md call MarkdownBlocks()
    au InsertLeave *.md call MarkdownBlocks()
    au BufWritePost *.md call MarkdownBlocks()
    au BufWritePost *.md hi markdownCodeBlockBG ctermbg=black guibg=#000000
    au BufEnter *.md hi markdownCodeBlockBG ctermbg=black guibg=#000000
    au BufWritePost *.md hi String ctermbg=black guibg=#000000
    au BufEnter *.md hi String ctermbg=black guibg=#000000
    au BufWritePost *.md hi Delimiter ctermbg=black guibg=#000000
    au BufEnter *.md hi Delimiter ctermbg=black guibg=#000000

    " trying to highlight percent code blocks
    "
    " au BufEnter *.jl call PercentBlocks()
    " au InsertLeave *.jl call PercentBlocks()
    " au BufWritePost *.jl call PercentBlocks()
    " au BufWritePost *.jl hi markdownCodeBlockBG ctermbg=black guibg=#000000
    " au BufEnter *.jl hi markdownCodeBlockBG ctermbg=black guibg=#000000
    " au BufWritePost *.jl hi String ctermbg=black guibg=#000000
    " au BufEnter *.jl hi String ctermbg=black guibg=#000000
    " au BufWritePost *.jl hi Delimiter ctermbg=black guibg=#000000
    " au BufEnter *.jl hi Delimiter ctermbg=black guibg=#000000

    au BufEnter *.jmd call MarkdownBlocks()
    au InsertLeave *.jmd call MarkdownBlocks()
    au BufWritePost *.jmd call MarkdownBlocks()
    au BufWritePost *.jmd hi markdownCodeBlockBG ctermbg=black guibg=#000000
    au BufEnter *.jmd hi markdownCodeBlockBG ctermbg=black guibg=#000000
    au BufWritePost *.jmd hi String ctermbg=black guibg=#000000
    au BufEnter *.jmd hi String ctermbg=black guibg=#000000
    au BufWritePost *.jmd hi Delimiter ctermbg=black guibg=#000000
    au BufEnter *.jmd hi Delimiter ctermbg=black guibg=#000000

augroup END
