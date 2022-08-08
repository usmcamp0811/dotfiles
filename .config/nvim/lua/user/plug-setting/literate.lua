local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  e = {
    c = { ":lua require'literate'.Comment()<CR>", "Comment"},
    t = { ":lua require'literate'.Tangle()<CR>", "Tangle" },
    s = { ":lua require'literate'.Edit()<CR>", "Edit" },
    q = { ":lua require'literate'.EditClose()<CR>", "Close Edit Window" },
  },
},
  { prefix = "<leader>" }
)
