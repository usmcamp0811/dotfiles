local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
	return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics
local completions = null_ls.builtins.completion
local hover = null_ls.builtins.hover
local code_actions = null_ls.builtins.code_actions

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
	on_attach = function(client, bufnr)
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					-- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
					vim.lsp.buf.formatting_sync()
				end,
			})
		end
	end,
})
