
local function make_conjure_command()
    local root = require('lspconfig').util.root_pattern('Project.toml')(vim.api.nvim_buf_get_name(0))
    if root == nil then
        root = "."
    end
    vim.g["conjure#client#julia#stdio#command"] = "julia --banner=no --color=no --project=" .. root
end

vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = "*.jl",
    callback = make_conjure_command,
})

vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = "*.clj",
    callback = make_conjure_command,
})

-- this seems to need something in it or things break when opening lua files
vim.g["conjure#filetypes"] = { "fennel" }
vim.g["conjure#mapping#doc_word"] = {"K"}
