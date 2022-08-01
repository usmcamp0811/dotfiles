local neorg = require('neorg')
neorg.setup {
          ensure_installed = { "norg",  },
          highlight = { enable = true },
          requires = { "core.export.markdown" },
          load = {
            ["core.defaults"] = {},
            ["core.integrations.treesitter"] = {
              config = {
                norg      = {
                  url = "https://github.com/nvim-neorg/tree-sitter-norg",
                  files = { "src/parser.c", "src/scanner.cc" },
                  branch = "main"
                },
                norg_meta = {
                  url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
                  files = { "src/parser.c" },
                  branch = "main"
                },
                norg_table = {
                  url = "https://github.com/nvim-neorg/tree-sitter-norg-table",
                  files = { "src/parser.c" },
                  branch = "main"
                }
              }
            },
            ["core.norg.qol.toc"] = {},

            ["core.norg.esupports.metagen"] = {
                config = {
                    type = "auto",
                }
            },
            ["core.keybinds"] = {
                config = {
                    hook = function(keybinds)
                      local status_ok, which_key = pcall(require, "which-key")
                      if not status_ok then
                        return
                      end

                      which_key.register({
                        t = {
                            name = "+Gtd",
                            c = "Capture",
                            e = "Edit",
                            v = "Views",
                        },
                        -- t = {
                        --   name = "GTD Base",
                        --   c = { "<Cmd>Neorg keybind norg core.gtd.base.capture<CR>", "Capture"},
                        --   v = { "<Cmd>Neorg keybind norg core.gtd.base.views<CR>", "Views"},
                        --   e = { "<Cmd>Neorg keybind norg core.gtd.base.edit<CR>", "Edit"},
                        -- },
                        m = {
                          name = "Neorg",
                          h = { ":Neorg mode traverse-heading<CR>", "Traverse Heading"},
                          n = { ":Neorg mode norg<CR>", "Neorg Mode"},
                          t = { "<Cmd>Neorg keybind norg core.norg.concealer.toggle-markup<CR>", "Toggle Markup"},
                        },
                        -- n = {
                        --   name = "Note",
                        -- },
                      },
                        { prefix = "," },
                        { mode = "n" }
                      )
                      which_key.register({
                          name = "Note",
                          -- l = { "<Cmd>Neorg keybind norg core.integrations.telescope.find_linkable<CR>", "Find Linkable"},
                          p = { ":Neorg presenter start<cr>", "Start Presentation"},
                          n = { "<Cmd>Neorg keybind norg core.norg.dirman.new.note<CR>", "New Note"},
                          j = { "::Neorg journal today<cr>", "Today's Journal" }
                      },
                      { prefix = "<Space>" }
                      )
                      -- which_key.register({
                      --     name = "Note",
                      --     l = { "<Cmd>core.integrations.telescope.insert_link<CR>", "Find Linkable"},
                      -- },
                      -- { mode = "v" }
                      -- )
                      which_key.register({
                          -- name = "Note",
                          ["<C-L>"] = { "<Cmd>Neorg keybind norg core.integrations.telescope.insert_link<CR>", "Insert Link"},
                          ["<C-s>"] = { ":w<CR>", "Save"},
                          -- not sure if I want to do these... cause they conflict with window movement
                          ["<C-j>"] = { "<Cmd>Neorg keybind norg core.integrations.treesitter.next.heading<CR>", "Next Heading" },
                          ["<C-k>"] = { "<Cmd>Neorg keybind norg core.integrations.treesitter.previous.heading<CR>", "Next Heading" },
                          M = { "0i|<esc>", "Marker" }
                      })
                      which_key.register({
                          name = "Note",
                          t = {
                            name = "Neorg Task Motions",
                            r = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_recurring<CR>", "Task Recurring"},
                            c = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_cancelled<CR>", "Task Cancelled"},
                            i = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_important<CR>", "Task Important"},
                            h = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_on_hold<CR>", "Task On Hold"},
                            p = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_pending<CR>", "Task Pending"},
                            u = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_undone<CR>", "Task Pending"},
                            d = { "<Cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_done<CR>", "Task Done"},
                          }
                      },
                        { prefix = "g" }
                      )
                      keybinds.unmap("norg", "n", "<C-s>")
                    end,
                }
            },
            ["core.norg.journal"] = {},
            ["core.integrations.telescope"] = {},
            ["core.gtd.base"] = {
              config = {
                workspace = "dashboard",
                default_lists = {
                  inbox = "inbox.norg",
                },
                syntax = {
                  context = "#contexts",
                  start = "#time.start",
                  due = "#time.due",
                  waiting = "#waiting.for",
                }
              }
            },
            ["external.gtd-project-tags"] = {},
            ["external.context"] = {},
            ["core.tangle"] = {},
            ["core.norg.manoeuvre"] = {},
            ["core.export"] = { config = {}},
            ["core.export.markdown"] = {
              config = {
                extensions = "all",
                },
            },
            ["core.presenter"] = {
              config = {
                zen_mode = "zen-mode",
                -- zen_mode = "truezen",
              },
            },
            ["external.kanban"] = {
              config = {
                task_states = {
                  "undone",
                  "done",
                  "pending",
                  "cancelled",
                  "uncertain",
                  "urgent",
                  "recurring",
                  "on_hold",
                }
              }
            },
            ["core.norg.concealer"] = {},
            ["core.norg.completion"] = {
                config = {
                    engine = "nvim-cmp", -- we current support nvim-compe and nvim-cmp only
                },
            },
            ["core.norg.dirman"] = {
                config = {
                    workspaces = {
                        work = "~/notes/work",
                        home = "~/notes/home",
                        dashboard = "~/notes/dashboard",
                    }
                }
            }
          }
        }


return neorg
