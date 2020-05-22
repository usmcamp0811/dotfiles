let g:slime_target = "x11"
xmap <leader>\ <Plug>SlimeRegionSend
nmap <leader>\ <Plug>SlimeParagraphSend
nmap <c-c>v     <Plug>SlimeConfig

function! _EscapeText_rmarkdown(text)
  " Remove all fences
  let trimmed = substitute(a:text, '```{.*}\n', '', 'g')
  let trimmed = substitute(trimmed, '```\n', '', 'g')
  " Detect language
  if match(a:text,'```{python}') > -1
    return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, trimmed, "--\n"]
  else
    return [trimmed]
  endif
endfunction
