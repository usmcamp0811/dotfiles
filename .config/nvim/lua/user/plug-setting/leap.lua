local leap = require("leap")

leap.setup({})
leap.set_default_keymaps()

vim.api.nvim_set_hl(0, "LeapMatch", { fg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelPrimary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapLabelSecondary", { bg = "#ff768e" })
vim.api.nvim_set_hl(0, "LeapBackdrop", { fg = "gray" })
