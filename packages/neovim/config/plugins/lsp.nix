{ pkgs, ... }: {
  # diagnostics.virtual_lines = { only_current_line = true; };
  plugins = {
    vim-slime = { enable = true; };
    conjure = { enable = true; };
    vimtex = { enable = true; };
    ts-context-commentstring = { enable = true; };
    conform-nvim = {
      enable = true;
      formattersByFt = {
        lua = [ "stylua" ];
        # Conform will run multiple formatters sequentially
        python = [ "isort" "black" ];
        # Use a sub-list to run only the first available formatter
        javascript = [[ "prettierd" "prettier" ]];
        # Use the "*" filetype to run formatters on all filetypes.
        "*" = [ "codespell" ];
        # Use the "_" filetype to run formatters on filetypes that don't
        # have other formatters configured.
        "_" = [ "trim_whitespace" ];
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
