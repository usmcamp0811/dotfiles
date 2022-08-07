local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  ["<leader><cr>"] = { ":ConjureEval<CR>", "EvalCode"},
},
  { prefix = "<leader>", mode = "v" }
)

which_key.register({
  ["<cr>"] = { ":ConjureEval<CR>", "EvalCode"},
},
  { prefix = "<leader>", mode = "n" }
)

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

-- -- Base Conjure Mappings
-- which_key.register({
--     l = {
--         name = "log",
--         s = "Open in new horizontal split window",
--         v = "Open in new vertical split window",
--         t = "Open in new tab",
--         q = "Close all visibal windows in current tab",
--         r = "Soft reset",
--         R = "Hard reset",
--     },
--     E = "Evaluate given motion",
--     e = {
--         name = "eval",
--         e = "Form under the cursor",
--         r = "Root form under the cursor",
--         w = "Word under the cursor",
--         c = {
--             name = "display as comment",
--             e = "Form under the cursor",
--             r = "Root form under the cursor",
--             w = "Word under the cursor",
--         },
--         ["!"] = "Replacing the Form under the cursor",
--         m = "Form at the given mark",
--         f = "File from disk",
--         b = "Current buffer",
--     },
--     g = {
--         name = "goto",
--         d = "Definition",
--     },
-- }, { prefix = "<leader>", })
--
-- which_key.register({
--     E = "Evaluate selection",
-- }, { prefix = "<leader>", mode = 'v' })

-- -- Clojure Nrepl Client Mappings
-- which_key.register({
--     c = {
--         name = "connection",
--         d = "Disconnect current",
--         f = "Connect",
--     },
--     ei = "Interrupt oldest",
--     v = {
--         name = "view",
--         e = "Last exception",
--         ["1"] = "Most recent evaluation",
--         ["2"] = "2nd most recent evaluation",
--         ["3"] = "3rd most recent evaluation",
--         s = "Source of symbol under cursor",
--     },
--     s = {
--         name = "session",
--         c = "Clone",
--         f = "Create fresh",
--         q = "Close current",
--         Q = "Close all",
--         l = "List",
--         n = "Next",
--         p = "Previous",
--         s = "Prompt to select",
--     },
--     t = {
--         name = "test",
--         a = "Run all loaded tests",
--         n = "Run tests in namespace",
--         N = "Run tests in testing namespace",
--         c = "Run under cursor",
--     },
--     r = {
--         name = "refresh",
--         r = "Changed namespaces",
--         a = "All, even unchanged",
--         c = "Clear refresh cache",
--     },
-- }, { prefix = "<leader>", })
