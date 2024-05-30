{
  autoCmd = [
    # General Settings
    {
      event = ["FileType"];
      pattern = ["qf" "help" "man" "lspinfo"];
      command = "nnoremap <silent> <buffer> q :close<CR>";
    }
    {
      event = ["TextYankPost"];
      pattern = ["*"];
      command = "silent!lua require('vim.highlight').on_yank({higroup = 'Visual', timeout = 200})";
    }
    {
      event = ["BufWinEnter"];
      pattern = ["*"];
      command = ":set formatoptions-=cro";
    }
    {
      event = ["FileType"];
      pattern = ["qf"];
      command = "set nobuflisted";
    }
    # Git
    {
      event = ["FileType"];
      pattern = ["gitcommit"];
      command = "setlocal wrap";
    }
    {
      event = ["FileType"];
      pattern = ["gitcommit"];
      command = "setlocal spell";
    }
    # Markdown
    {
      event = ["FileType"];
      pattern = ["markdown"];
      command = "setlocal wrap";
    }
    {
      event = ["FileType"];
      pattern = ["markdown"];
      command = "setlocal spell";
    }
    # Auto Resize
    {
      event = ["VimResized"];
      pattern = ["*"];
      command = "tabdo wincmd =";
    }
    # Alpha
    {
      event = ["User"];
      pattern = ["AlphaReady"];
      command = "set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2";
    }
    # Julia
    {
      event = ["FileType"];
      pattern = ["julia"];
      command = "set foldmethod=syntax";
    }
    # Restore Cursor Position
    {
      event = ["BufReadPost"];
      pattern = ["*"];
      command = ''
        if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif'';
    }

    # Trigger `autoread` when files change on disk
    {
      event = ["FocusGained" "BufEnter" "CursorHold" "CursorHoldI"];
      pattern = ["*"];
      command = "if mode() !~ '\\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif";
    }
    {
      event = ["FileChangedShellPost"];
      pattern = ["*"];
      command = ''
        echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None'';
    }

    # Map Esc to Caps Lock on VimEnter
    {
      event = ["VimEnter"];
      pattern = ["*"];
      command = "silent! !xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'";
    }

    # Save manual folds automatically
    {
      event = ["BufWrite"];
      pattern = ["*"];
      command = "mkview";
    }
    {
      event = ["BufRead"];
      pattern = ["*"];
      command = "silent! loadview";
    }

    # Set indent folds for python
    {
      event = ["FileType"];
      pattern = ["python"];
      command = "set foldmethod=indent";
    }

    # Display images for specific file types
    {
      event = ["BufRead"];
      pattern = ["*.png" "*.jpg" "*.jpeg"];
      command = ":call DisplayImage()";
    }
  ];
}
