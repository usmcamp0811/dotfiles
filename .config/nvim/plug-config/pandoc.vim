augroup pandoc_syntax
    au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
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
    au BufWritePost *.md hi markdownCodeBlockBG ctermbg=black guibg=#21242b
    au BufEnter *.md hi markdownCodeBlockBG ctermbg=black guibg=#21242b
    au BufWritePost *.md hi String ctermbg=black guibg=#21242b
    au BufEnter *.md hi String ctermbg=black guibg=#21242b
    au BufWritePost *.md hi Delimiter ctermbg=black guibg=#21242b
    au BufEnter *.md hi Delimiter ctermbg=black guibg=#21242b
augroup END
