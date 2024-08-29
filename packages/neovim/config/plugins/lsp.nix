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
      settings = {
        format_on_save = {
          timeout_ms = 500;
          lsp_format = "fallback";
        };
        notify_on_error = true;
        formatters_by_ft = {
          c = [ "clang-format" ];
          cpp = [ "clang-format" ];
          json = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
          };
          lua = [ "stylua" ];
          markdown = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
          };
          nix = [ "nixfmt" ];
          python = [ "isort" "black" ];
          rust = [ "rustfmt" ];
          sh = [ "shfmt" ];
          sql = {
            __unkeyed-1 = "pg_format";
            __unkeyed-2 = "sql_formatter";
            # __unkeyed-3 = "sqlfluff"; # breaks flink sql
          };
          yaml = [ "prettierd" ];
        };
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
