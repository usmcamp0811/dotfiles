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
