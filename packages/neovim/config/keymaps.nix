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
      action = "<cmd>Telescope git_files theme=ivy<cr>";
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

  files."after/ftplugin/markdown.lua".keymaps = [{
    mode = "n";
    key = "<leader>f";
    options = { desc = "Reformat lines to 110 chars"; };
    action = ":%!fmt -w 110 -s<CR>";
  }];
  files."after/ftplugin/python.lua".keymaps = [
    {
      mode = "n";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
    {
      mode = "n";
      key = "<leader>cct";
      options = { desc = "Get Python REPL"; };
      action = ":lua vim.b.slime_config = {jobid=vim.g.python_job_id}<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<CR>";
      options = { desc = "Execute Code Cell <marks>"; };
      action = ":MoltenEvaluateLine<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<S-CR>";
      options = { desc = "Run Whole File"; };
      action = "ggvG :'<,'>SlimeSend<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc<CR>";
      options = { desc = "Run Code w/ Conjure"; };
      action = ":'<,'>ConjureEval<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
  ];

  files."after/ftplugin/julia.lua".keymaps = [
    {
      mode = "n";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
    {
      mode = "n";
      key = "<leader>cct";
      options = { desc = "Get Julia REPL"; };
      action = ":lua vim.b.slime_config = {jobid=vim.g.julia_job_id}<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<CR>";
      options = { desc = "Run w/ Julia Cell / Slime"; };
      action = ":JuliaCellExecuteCell<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<S-CR>";
      options = { desc = "Run Whole File"; };
      action = "ggvG :'<,'>SlimeSend<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc<CR>";
      options = { desc = "Run Code w/ Slime"; };
      action = ":'<,'>SlimeSend<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
  ];

  files."after/ftplugin/clojure.lua".keymaps = [
    {
      mode = "n";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
    {
      mode = "n";
      key = "<leader>cct";
      options = { desc = "Get Clojure REPL"; };
      action = ":lua vim.b.slime_config = {jobid=vim.g.clojure_job_id}<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<CR>";
      options = { desc = "Execute Code"; };
      action =
        ":ConjureEvalCurrentForm<CR>:silent! call repeat#set(' ee', 1)<CR>";
    }
    {
      mode = "n";
      key = "<leader>cc<S-CR>";
      options = { desc = "Run Whole File"; };
      action = "ggvG :'<,'>SlimeSend<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc<CR>";
      options = { desc = "Run Code w/ Slime"; };
      action = ":'<,'>SlimeSend<CR>";
    }
    {
      mode = "v";
      key = "<leader>cc?";
      options = { desc = "LSP Hover Definition"; };
      action = ":lua vim.lsp.buf.hover()<CR>";
    }
  ];
}
