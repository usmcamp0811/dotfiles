local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
	return
end

local lspconfig = require("lspconfig")

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics
local completions = null_ls.builtins.completion
local hover = null_ls.builtins.hover
local code_actions = null_ls.builtins.code_actions

local on_attach = function(client)
	-- client.resolved_capabilities.document_range_formatting = true
	-- client.resolved_capabilities.document_formatting = true
	if client.resolved_capabilities.document_formatting then
		vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()")
	end
end

null_ls.setup({
	debug = false,
	sources = {
		formatting.prettier.with({ extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" } }),
		formatting.black.with({ extra_args = { "--fast" } }),
		formatting.stylua,
		formatting.markdownlint,
		formatting.beautysh,
		formatting.bibclean,
		formatting.cljstyle,
		formatting.djhtml,
		formatting.fixjson,
		diagnostics.flake8,
		diagnostics.zsh,
		diagnostics.alex,
		diagnostics.ansiblelint,
		diagnostics.clj_kondo,
		diagnostics.curlylint,
		diagnostics.djlint,
		diagnostics.jsonlint,
		diagnostics.pydocstyle,
		diagnostics.shellcheck,
		diagnostics.vint,
		diagnostics.yamllint,
		code_actions.proselint,
		code_actions.refactoring,
		completions.spell,
		completions.vsnip,
		hover.dictionary,
	},
	debounce = 400,
	on_attach = on_attach,
})
