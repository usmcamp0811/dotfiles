{ pkgs, ... }: {
  plugins = {
    magma-nvim = {
      enable = true;
      settings = {
        image_provider = "kitty";
        wrap_output = true;
      };
    };
    vim-slime = { enable = true; };
    conjure = { enable = true; };
    vimtex = { enable = true; };
    ts-context-commentstring = { enable = true; };
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
        bashls = { enable = true; };
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
