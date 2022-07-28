
vim.cmd "highlight CodiVirtualText guifg=cyan"
vim.g["codi#virtual_text_prefix"] = "❯ "
vim.g["codi#interpreters"] = {
  python = {
    bin = "python",
    prompt = "^\\(>>>\\|\\.\\.\\.\\) ",
  },
  Julia = {
    bin = {"julia", "-qi", "--color=no", "--history-file=no", "--startup-file=no"},
    prompt = "^\\(julia>\\) "
  }
}

vim.g["codi#log"] = "/home/mcamp/codi_log"
vim.g["codi#raw"] = 0
vim.g["codi#rightalign"] = 1

