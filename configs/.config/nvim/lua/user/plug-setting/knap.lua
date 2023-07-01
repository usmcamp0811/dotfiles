-- set shorter name for keymap function
local kmap = vim.keymap.set

-- F5 processes the document once, and refreshes the view
kmap('i','<F5>', function() require("knap").process_once() end)
kmap('v','<F5>', function() require("knap").process_once() end)
kmap('n','<F5>', function() require("knap").process_once() end)

-- F6 closes the viewer application, and allows settings to be reset
kmap('i','<F6>', function() require("knap").launch_viewer() end)
kmap('v','<F6>', function() require("knap").launch_viewer() end)
kmap('n','<F6>', function() require("knap").launch_viewer() end)

-- F7 toggles the auto-processing on and off
kmap('i','<F7>', function() require("knap").toggle_autopreviewing() end)
kmap('v','<F7>', function() require("knap").toggle_autopreviewing() end)
kmap('n','<F7>', function() require("knap").toggle_autopreviewing() end)

-- F8 invokes a SyncTeX forward search, or similar, where appropriate
kmap('i','<F8>', function() require("knap").forward_jump() end)
kmap('v','<F8>', function() require("knap").forward_jump() end)
kmap('n','<F8>', function() require("knap").forward_jump() end)

local gknapsettings = {
    texoutputext = "pdf",
    textopdfforwardjump = "zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%",
    textopdfviewerlaunch = "zathura --synctex-editor-command 'nvim --headless -es --cmd \"lua require('\"'\"'knaphelper'\"'\"').relayjump('\"'\"'%servername%'\"'\"','\"'\"'%{input}'\"'\"',%{line},0)\"' %outputfile%",
    textopdfviewerrefresh = "none"
}

vim.g.knap_settings = gknapsettings

-- vim.cmd[[ 
-- let g:knap_settings = {
--     \ "textopdfviewerlaunch": "zathura --synctex-editor-command 'nvim --headless -es --cmd \"lua require('\"'\"'knaphelper'\"'\"').relayjump('\"'\"'%servername%'\"'\"','\"'\"'%{input}'\"'\"',%{line},0)\"' %outputfile%",
--     \ "textopdfviewerrefresh": "none",
--     \ "textopdfforwardjump": "zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%"
-- \ }
-- ]]
-- local gknapsettings = {
--     texoutputext = "pdf",
--     textopdf = "pdflatex -synctex=1 -halt-on-error -interaction=batchmode %docroot%",
--     textopdfviewerlaunch = "mupdf %outputfile%",
--     textopdfviewerrefresh = "kill -HUP %pid%"
-- }
-- vim.g.knap_settings = gknapsettings
