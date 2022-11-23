local leap = require("leap")

leap.set_default_keymaps()

vim.api.nvim_set_hl(0, "LeapMatch", { fg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelPrimary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelSecondary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapBackdrop", { fg = "gray" })

leap.setup({
max_phase_one_targets = nil,
highlight_unlabeled_phase_one_targets = false,
max_highlighted_traversal_targets = 10,
case_sensitive = false,
equivalence_classes = { ' \t\r\n', },
substitute_chars = {},
-- safe_labels = { 's', 'f', 'n', 'u', 't', . . . },
-- labels = { 's', 'f', 'n', 'j', 'k', . . . },
special_keys = {
  repeat_search = '<enter>',
  next_phase_one_target = '<enter>',
  next_target = {'<enter>', ';'},
  prev_target = {'<tab>', ','},
  next_group = '<space>',
  prev_group = '<tab>',
  multi_accept = '<enter>',
  multi_revert = '<backspace>',
}
})

require('flit').setup {
  keys = { f = 'f', F = 'F', t = 't', T = 'T' },
  -- A string like "nv", "nvo", "o", etc.
  labeled_modes = "v",
  multiline = true,
  -- Like `leap`s similar argument (call-specific overrides).
  -- E.g.: opts = { equivalence_classes = {} }
  opts = {}
}
