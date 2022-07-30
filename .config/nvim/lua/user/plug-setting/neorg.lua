local neorg = require('neorg')
neorg.setup {
          ensure_installed = { "norg",  },
          highlight = { enable = true },
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
            ["core.norg.journal"] = {},
            ["core.integrations.telescope"] = {},
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
                    }
                }
            }
          }
        }
return neorg
