{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [knap];
  extraConfigLua = ''
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
        textopdfforwardjump = "${pkgs.zathura}/bin/zathura --synctex-forward=%line%:%column%:%srcfile% %outputfile%",
        textopdfviewerlaunch = "${pkgs.zathura}/bin/zathura --synctex-editor-command 'nvim --headless -es --cmd \"lua require('\"'\"'knaphelper'\"'\"').relayjump('\"'\"'%servername%'\"'\"','\"'\"'%{input}'\"'\"',%{line},0)\"' %outputfile%",
        textopdfviewerrefresh = "none",

        mdtohtmlviewerlaunch = "SRC=%srcfile%; ID=\"''${SRC//[^A-Za-z0-9]/_-_-}\"; ${pkgs.qutebrowser}/bin/qutebrowser --target window %outputfile% \":spawn --userscript knap-userscript.lua $ID\"",
        mdtohtmlviewerrefresh = "SRC=%srcfile%; ID=\"''${SRC//[^A-Za-z0-9]/_-_-}\"; echo ':run-with-count '$(</tmp/knap-$ID-qute-tabindex)' reload -f' > \"$(</tmp/knap-$ID-qute-fifo)\"",
        htmltohtml = "none",
        htmltohtmlviewerlaunch = "SRC=%srcfile%; ID=\"''${SRC//[^A-Za-z0-9]/_-_-}\"; ${pkgs.qutebrowser}/bin/qutebrowser --target window %outputfile% \":spawn --userscript knap-userscript.lua $ID\"",
        htmltohtmlviewerrefresh = "SRC=%srcfile%; ID=\"''${SRC//[^A-Za-z0-9]/_-_-}\"; echo ':run-with-count '$(</tmp/knap-$ID-qute-tabindex)' reload -f' > \"$(</tmp/knap-$ID-qute-fifo)\"",


        markdownoutputext = "html",
        markdowntohtml = "${pkgs.pandoc}/bin/pandoc --standalone %docroot% -o %outputfile%",


        pumloutputext = "png",
        pumltopng = "${pkgs.plantuml-c4}/bin/plantuml -tpng %docroot%",
        pumltopngviewerlaunch = "${pkgs.nodePackages.live-server}/bin/live-server --quiet --browser=${pkgs.qutebrowser}/bin/qutebrowser --open=%outputfile% --watch=%outputfile% --wait=400",
        pumltopngviewerrefresh = "none"
    }

    vim.g.knap_settings = gknapsettings

  '';
}
