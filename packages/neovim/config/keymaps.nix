{
  keymaps = [
    {
      mode = "n";
      key = "<Space>";
      action = "<Nop>";
    }
    {
      mode = "n";
      key = ",";
      action = "<Nop>";
    }
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = ":bnext<CR>";
    }
    {
      mode = "n";
      key = "<S-h>";
      action = ":bprevious<CR>";
    }
    {
      mode = "n";
      key = "<C-s>";
      action = ":w<CR>";
    }
    {
      mode = "n";
      key = "<C-q>";
      action = ":q<CR>";
    }
    {
      mode = "n";
      key = "Y";
      action = "y$";
    }
    {
      mode = "n";
      key = "<C-Up>";
      action = ":resize -2<CR>";
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = ":resize +2<CR>";
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = ":vertical -2<CR>";
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = ":vertical +2<CR>";
    }
    {
      mode = "n";
      key = "<S-D>";
      action = "5<C-e>";
    }
    {
      mode = "n";
      key = "<S-E>";
      action = "5<C-y>";
    }
    {
      mode = "n";
      key = "T";
      action = ":r! date +'- \\%H:\\%M - '<CR>A";
    }
    {
      mode = "n";
      key = "<F8>";
      action = ":set list!<CR>";
    }
    {
      mode = "n";
      key = "F";
      action = "<cmd>Telescope live_grep theme=ivy<cr>";
    }
    {
      mode = "v";
      key = "J";
      action = ":move '>+1<CR>gv-gv";
    }
    {
      mode = "v";
      key = "K";
      action = ":move '<-2<CR>gv-gv";
    }
    {
      mode = "v";
      key = "<Tab>";
      action = ">";
    }
    {
      mode = "v";
      key = "<S-Tab>";
      action = "<";
    }
    {
      mode = "i";
      key = "<C-s>";
      action = "<esc>:w<cr>";
    }
    {
      mode = "i";
      key = "<C-q>";
      action = "<esc>:Bclose<cr>";
    }
    {
      mode = "i";
      key = "<F8>";
      action = "<C-o>:set list!<CR>";
    }
    {
      mode = "c";
      key = "<F8>";
      action = "<C-o>:set list!<CR>";
    }
  ];
}

