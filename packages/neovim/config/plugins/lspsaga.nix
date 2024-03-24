{
  plugins.lspsaga = {
    enable = true;

    ui = {
      border = "single";
      devicon = true;
      title = true;
      expand = "⊞";
      collapse = "⊟";
      codeAction = "💡";
      actionfix = "";
      kind = { };
      impSign = "󰳛 ";
    };

    hover = {
      maxWidth = 0.9;
      maxHeight = 0.8;
      openLink = "gx";
      openCmd = "!chrome";
    };

    diagnostic = {
      showCodeAction = true;
      showLayout = "float";
      showNormalHeight = 10;
      jumpNumShortcut = true;
      maxWidth = 0.8;
      maxHeight = 0.6;
      maxShowWidth = 0.9;
      maxShowHeight = 0.6;
      textHlFollow = true;
      borderFollow = true;
      extendRelatedInformation = false;
      diagnosticOnlyCurrent = false;
    };

    codeAction = {
      numShortcut = true;
      showServerName = false;
      extendGitSigns = false;
      onlyInCursor = true;
      keys = {
        quit = "q";
        exec = "<CR>";
      };
    };

    lightbulb = {
      enable = true;
      sign = true;
      debounce = 10;
      signPriority = 40;
      virtualText = true;
    };

    scrollPreview = {
      scrollDown = "<C-f>";
      scrollUp = "<C-b>";
    };

    finder = {
      maxHeight = 0.5;
      leftWidth = 0.3;
      rightWidth = 0.3;
      methods = { };
      default = "ref+imp";
      layout = "float";
      silent = false;
      filter = { };
      keys = {
        shuttle = "[w";
        toggleOrOpen = "o";
        vsplit = "s";
        split = "i";
        tabe = "t";
        tabnew = "r";
        quit = "q";
        close = "<C-c>k";
      };
    };

    definition = {
      width = 0.6;
      height = 0.5;
      keys = {
        edit = "<C-c>o";
        vsplit = "<C-c>v";
        split = "<C-c>i";
        tabe = "<C-c>t";
        quit = "q";
        close = "<C-c>k";
      };
    };

    rename = {
      inSelect = true;
      autoSave = false;
      projectMaxWidth = 0.5;
      projectMaxHeight = 0.5;
      keys = {
        quit = "<C-k>";
        exec = "<CR>";
        select = "x";
      };
    };

    symbolInWinbar = {
      enable = true;
      separator = " › ";
      hideKeyword = false;
      showFile = true;
      folderLevel = 1;
      colorMode = true;
      delay = 300;
    };

    outline = {
      winPosition = "right";
      winWidth = 30;
      autoPreview = true;
      detail = true;
      autoClose = true;
      closeAfterJump = false;
      layout = "normal";
      maxHeight = 0.5;
      leftWidth = 0.3;
      keys = {
        toggleOrJump = "o";
        quit = "q";
        jump = "e";
      };
    };

    callhierarchy = {
      layout = "float";
      keys = {
        edit = "e";
        vsplit = "s";
        split = "i";
        tabe = "t";
        close = "<C-c>k";
        quit = "q";
        shuttle = "[w";
        toggleOrReq = "u";
      };
    };

    implement = {
      enable = true;
      sign = true;
      virtualText = true;
      priority = 100;
    };

    beacon = {
      enable = true;
      frequency = 7;
    };
  };
  extraConfigLua = ''
    local wk = require("which-key")

    wk.register({
      g = {
        name = "LSPSaga",
        h = { ":Lspsaga lsp_finder<CR>", "Finder" },
        a = { ":Lspsaga code_action<CR>", "Code Action" },
        s = { ":Lspsaga signature_help<CR>", "Signature Help" },
        r = { ":Lspsaga rename<CR>", "Rename" },
        d = { ":Lspsaga preview_definition<CR>", "Preview Definition" },
      },
      ["<leader>"] = {
        c = {
          name = "LSPSaga Diagnostics",
          d = { ":Lspsaga show_line_diagnostics<CR>", "Line Diagnostics" },
          c = { ":Lspsaga show_cursor_diagnostics<CR>", "Cursor Diagnostics" },
        },
      },
      K = { ":Lspsaga hover_doc<CR>", "Hover Doc" },
      ["<C-f>"] = { "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(1)<CR>", "Scroll Doc Down" },
      ["<C-b>"] = { "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(-1)<CR>", "Scroll Doc Up" },
    })
  '';
}
