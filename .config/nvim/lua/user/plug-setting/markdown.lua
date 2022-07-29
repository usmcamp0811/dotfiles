vim.g.vim_markdown_conceal = 1
vim.o.conceallevel=2
vim.g.vim_markdown_conceal_code_blocks = 1
vim.g.vim_markdown_fenced_languages = { 'julia','julia=md', 'python', 'bash=sh', 'viml=vim', 'javascript=js', 'zsh', 'bash=sh'}
vim.g.markdown_folding = 1

vim.o.foldmethod = "expr"
vim.cmd "set foldexpr=nvim_treesitter#foldexpr()"
