let $autocorrect=0
function AutoCorrectToggle()
if $autocorrect==0
    :exe "normal :EnableAutocorrect<CR>"
    let $autocorrect=1
else
    :exe "normal :DisableAutocorrect<CR>"
    let $autocorrect=0
endif
endfunction

nnoremap <F7> :call AutoCorrectToggle()<CR>
