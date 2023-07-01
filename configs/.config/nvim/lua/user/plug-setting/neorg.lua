local neorg = require("neorg")

neorg.setup({
  ensure_installed = { "norg" },
  highlight = { enable = true },
  requires = { "core.export.markdown" },
  load = {
    ["core.defaults"] = {},
    ["core.summary"] = {},
    ["core.integrations.treesitter"] = {
      config = {
        norg = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg",
          files = { "src/parser.c", "src/scanner.cc" },
          branch = "main",
        },
        norg_meta = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
          files = { "src/parser.c" },
          branch = "main",
        },
        norg_table = {
          url = "https://github.com/nvim-neorg/tree-sitter-norg-table",
          files = { "src/parser.c" },
          branch = "main",
        },
      },
    },
    ["core.keybinds"] = {
      config = {
        hook = function(keybinds)
          local status_ok, which_key = pcall(require, "which-key")
          if not status_ok then
            return
          end
          which_key.register({
            m = {
              name = "Neorg",
              h = { ":Neorg mode traverse-heading<CR>", "Traverse Heading" },
              n = { ":Neorg mode norg<CR>", "Neorg Mode" },
              t = { "<Cmd>Neorg keybind norg core.norg.concealer.toggle-markup<CR>", "Toggle Markup" },
            },
          }, { prefix = "," }, { mode = "n" })
          which_key.register({
            name = "Note",
            p = { ":Neorg presenter start<cr>", "Start Presentation" },
            j = { ":Neorg journal today<cr>", "Today's Journal" },
          }, { prefix = "<Space>" })
          which_key.register({
            ["<C-s>"] = { ":w<CR>", "Save" },
            ["<C-j>"] = {
              "<Cmd>Neorg keybind norg core.integrations.treesitter.next.heading<CR>",
              "Next Heading",
            },
            ["<C-k>"] = {
              "<Cmd>Neorg keybind norg core.integrations.treesitter.previous.heading<CR>",
              "Next Heading",
            },
          })
          which_key.register({
            name = "Note",
            t = {
              name = "Neorg Task Motions",
              r = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_recurring<CR>",
                "Task Recurring",
              },
              c = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_cancelled<CR>",
                "Task Cancelled",
              },
              i = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_important<CR>",
                "Task Important",
              },
              h = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_on_hold<CR>",
                "Task On Hold",
              },
              p = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_pending<CR>",
                "Task Pending",
              },
              u = {
                "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_undone<CR>",
                "Task Pending",
              },
              d = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_done<CR>", "Task Done" },
            },
          }, { prefix = "g" })
          keybinds.unmap("norg", "n", "<C-s>")
        end,
      },
    },
  },
})

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.register({
  name = "Note",
  n = { ":Neorg workspace home<cr>", "Find Linkable" },
}, { prefix = "<Space>" })

return neorg
