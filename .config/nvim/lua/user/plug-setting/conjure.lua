local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  ["<leader><cr>"] = { ":ConjureEval<CR>", "EvalCode"},
},
  { mode = "v" }
)

which_key.register({
  ["<leader><cr>"] = { ":ConjureEval<CR>", "EvalCode"},
},
  { mode = "n" }
)
