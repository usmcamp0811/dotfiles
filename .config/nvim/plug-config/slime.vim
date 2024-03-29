xmap <c-\> <Plug>SlimeRegionSend
nmap <c-\> <Plug>SlimeParagraphSend
nmap <c-c>v     <Plug>SlimeConfig

" let g:slime_target = "tmux"
let g:slime_target = "x11"
let g:slime_default_config = {"socket_name": "default", "target_pane": "{last}"}
" let g:slime_cell_delimiter = "# %%"
let g:slime_cell_delimiter = "```"
" let g:slime_cell_delimiter = "# {{{"

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



