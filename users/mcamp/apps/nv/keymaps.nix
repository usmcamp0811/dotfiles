{
  keymaps = {
    normal = {
      "<Space>" = "<Nop>";
      "," = "<Nop>";
      "<C-h>" = "<C-w>h";
      "<C-j>" = "<C-w>j";
      "<C-k>" = "<C-w>k";
      "<C-l>" = "<C-w>l";
      "<S-l>" = ":bnext<CR>";
      "<S-h>" = ":bprevious<CR>";
      "<C-s>" = ":w<CR>";
      "<C-q>" = ":q<CR>";
      Y = "y$";
      "<C-Up>" = ":resize -2<CR>";
      "<C-Down>" = ":resize +2<CR>";
      "<C-Left>" = ":vertical -2<CR>";
      "<C-Right>" = ":vertical +2<CR>";
      "<S-D>" = "5<C-e>";
      "<S-E>" = "5<C-y>";
      T = ":r! date +'- \\%H:\\%M - '<CR>A";
      "<F8>" = ":set list!<CR>";
    };
    visual = {
      p = '"_dP';
    };
    visualBlock = {
      J = ":move '>+1<CR>gv-gv";
      K = ":move '<-2<CR>gv-gv";
      "<Tab>" = ">";
      "<S-Tab>" = "<";
    };
    insert = {
      "<C-s>" = "<esc>:w<cr>";
      "<C-q>" = "<esc>:Bclose<cr>";
      "<F8>" = "<C-o>:set list!<CR>";
    };
    command = {
      "<F8>" = "<C-o>:set list!<CR>";
    };
  };
}
