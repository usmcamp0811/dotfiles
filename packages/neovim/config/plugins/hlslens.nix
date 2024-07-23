{ pkgs, ... }: {
  extraPlugins = with pkgs.vimPlugins; [ nvim-hlslens ];

  keymaps = [
    {
      mode = "n";
      key = "n";
      options = { desc = "Next search match with hlslens"; };
      action =
        ":execute('normal! ' . v:count1 . 'n')<CR>:lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "N";
      options = { desc = "Previous search match with hlslens"; };
      action =
        ":execute('normal! ' . v:count1 . 'N')<CR>:lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "*";
      options = { desc = "Search forward with hlslens"; };
      action = "*<Cmd>lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "#";
      options = { desc = "Search backward with hlslens"; };
      action = "#<Cmd>lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "g*";
      options = { desc = "Search forward for word under cursor with hlslens"; };
      action = "g*<Cmd>lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "g#";
      options = {
        desc = "Search backward for word under cursor with hlslens";
      };
      action = "g#<Cmd>lua require('hlslens').start()<CR>";
    }
    {
      mode = "n";
      key = "<Leader>z";
      options = { desc = "Clear search highlighting"; };
      action = ":noh<CR>";
    }
  ];
  extraConfigLua = ''
    local kopts = {noremap = true, silent = true}
  '';
}
