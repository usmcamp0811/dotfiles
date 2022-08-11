local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
  return
end

require "user.lsp.configs"
require("user.lsp.handlers").setup()
require("user.lsp.mason")
require "lspconfig".pyright.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".eslint.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".julials.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".dockerls.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".bashls.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".ltex.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".jedi_language_server.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".clojure_lsp.setup { on_attach = require "lsp-format".on_attach }
require "lspconfig".sumneko_lua.setup { on_attach = require "lsp-format".on_attach }
require("lsp-format").setup {}
require "user.lsp.null-ls"


local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  l = {
    name = "LSP",
    a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
    d = {
      "require('lsp_lines').toggle",
      "Document Diagnostics",
    },
    w = {
      "<cmd>Telescope lsp_workspace_diagnostics<cr>",
      "Workspace Diagnostics",
    },
    f = { "<cmd>lua vim.lsp.buf.format{async=true}<cr>", "Format" },
    i = { "<cmd>LspInfo<cr>", "Info" },
    I = { "<cmd>LspInstallInfo<cr>", "Installer Info" },
    j = {
      "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>",
      "Next Diagnostic",
    },
    k = {
      "<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>",
      "Prev Diagnostic",
    },
    l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "CodeLens Action" },
    q = { "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", "Quickfix" },
    -- r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
    r = { "<cmd>lua Lspsaga rename<cr>", "Rename" },
    s = { "<cmd>Telescope lsp_document_symbols<cr>", "Document Symbols" },
    S = {
      "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
      "Workspace Symbols",
    },
  },
},
  { prefix = "<leader>" }
)
