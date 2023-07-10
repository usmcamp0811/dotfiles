local M = {}

local config = {
	minimap_width = 20,
	width_multiplier = 4,
	use_lsp = true,
	use_treesitter = true,
	exclude_filetypes = {},
	z_index = 1,
}

function M.get()
	return config
end

function M.setup(new_config)
	for k, v in pairs(new_config) do
		config[k] = v
	end
end

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
which_key.register({
	w = { ":lua require('codewindow').toggle_minimap()<CR>", "Toggle Code Window" },
}, { mode = "n", silent = true, noremap = true, buffer = bufnr, prefix = "<leader>" })
return M
