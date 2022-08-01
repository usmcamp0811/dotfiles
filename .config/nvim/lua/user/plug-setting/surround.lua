local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  a = {
    name = "Actions",
    c = { ":ColorizerToggle<cr>", "Colorizer"},
    u = { 'm`yypVr=``', 'underline-double' },
    ['"'] = { '<Plug>Ysurroundiw"', 'Surround word with "'},
    ["'"] = { "<Plug>Ysurroundiw'", "Surround word with '"},
    ["]"] = { "<Plug>Ysurroundiw]", "Surround word with ]"},
    ["}"] = { "<Plug>Ysurroundiw}", "Surround word with }"},
    [")"] = { "<Plug>Ysurroundiw)", "Surround word with ) `dw)`"},
    d = { '<Plug>Dsurround"', 'Delete " from around something'},
    s = { "<Plug>Dsurround'", "Delete ' from around something"},
  },
},
  { prefix = "<leader>" }
)
