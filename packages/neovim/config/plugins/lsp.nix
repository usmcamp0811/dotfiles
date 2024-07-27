{ pkgs, ... }: {
  extraConfigLuaPost = ''
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  '';

  extraPackages = with pkgs; [
    black
    clang-tools
    isort
    nixfmt-rfc-style
    nixfmt-classic
    nixpkgs-fmt
    pgformatter
    prettierd
    shfmt
    sqlfluff
    stylua
    nodePackages.prettier
  ];

  keymaps = [{
    key = "<leader>cf";
    action.__raw = "function() require('conform').format() end";
    mode = [ "n" "v" ];
    options = {
      silent = true;
      noremap = true;
      desc = "[C]onform: [F]ormat current buffer";
    };
  }];
  # diagnostics.virtual_lines = { only_current_line = true; };
  plugins = {
    vim-slime = { enable = true; };
    conjure = { enable = true; };
    vimtex = { enable = true; };
    ts-context-commentstring = { enable = true; };
    conform-nvim = {
      enable = true;
      formatOnSave = {
        lspFallback = true;
        timeoutMs = 500;
      };
      notifyOnError = true;
      formattersByFt = {
        c = [ "clang-format" ];
        cpp = [ "clang-format" ];
        json = [[ "prettierd" "prettier" ]];
        lua = [ "stylua " ];
        markdown = [[ "prettierd" "prettier" ]];
        nix = [ [ "nixfmt" ] ];
        python = [ "isort" "black" ];
        rust = [ "rustfmt" ];
        sh = [ "shfmt " ];
        sql = [[ "pg_format" "sql_formatter" "sqlfluff" ]];
        yaml = [ "prettierd" ];
      };
    };

    comment = {
      enable = true;
      settings = {
        toggler = {
          block = "<BS>";
          line = "<BS><BS>";
        };
        opleader = { line = "<BS>"; };
      };
    };

    lsp = {
      enable = true;
      servers = {
        julials = { enable = true; };
        jsonls = { enable = true; };
        cssls = { enable = true; };
        graphql = { enable = true; };

        pyright = { enable = true; };
        yamlls = { enable = true; };
        vuels = { enable = true; };
        html = { enable = true; };
        eslint = { enable = true; };
        lua-ls = { enable = true; };
        # bashls = { enable = true; };
        ccls = { enable = true; };
        terraformls = { enable = true; };
        texlab = { enable = true; };
        sqls = { enable = true; };
        java-language-server = { enable = true; };
        cmake = { enable = true; };
        dockerls = { enable = true; };
        nixd = { enable = true; };
      };
    };
  };
}
