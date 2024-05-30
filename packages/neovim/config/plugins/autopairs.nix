{
  plugins = {nvim-autopairs.enable = true;};

  extraConfigLua = ''
    -- Setup nvim-cmp.
    local status_ok, npairs = pcall(require, "nvim-autopairs")
    if not status_ok then
    	return
    end
    local Rule = require('nvim-autopairs.rule')


    npairs.setup({
    	check_ts = false,
    	ts_config = {
    		lua = { "string", "source" },
    		javascript = { "string", "template_string" },
        norg = false,
    	},
      disable_filetype = { "TelescopePrompt", "spectre_panel" },
    	fast_wrap = {
    		map = "<C-e>",
    		chars = { "{", "[", "(", '"', "'" },
    		-- pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
        pattern = [=[[%'%"%)%>%]%)%}%,]]=],
    		offset = 0, -- Offset from pattern match
    		end_key = "$",
    		keys = "qwertyuiopzxcvbnmasdfghjkl",
    		check_comma = true,
    		highlight = "PmenuSel",
    		highlight_grey = "LineNr",
    	},
    })


    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    local cmp_status_ok, cmp = pcall(require, "cmp")
    if not cmp_status_ok then
    	return
    end
    -- cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done({ map_char = { tex = "" } }))
    local handlers = require('nvim-autopairs.completion.handlers')
    cmp.event:on(
      'confirm_done',
      cmp_autopairs.on_confirm_done({
        filetypes = {
          -- "*" is a alias to all filetypes
          ["*"] = {
            ["("] = {
              kind = {
                cmp.lsp.CompletionItemKind.Function,
                cmp.lsp.CompletionItemKind.Method,
              },
              handler = handlers["*"]
            }
          },
          lua = {
            ["("] = {
              kind = {
                cmp.lsp.CompletionItemKind.Function,
                cmp.lsp.CompletionItemKind.Method
              },
              ---@param char string
              ---@param item item completion
              ---@param bufnr buffer number
              handler = function(char, item, bufnr)
                -- Your handler function. Inpect with print(vim.inspect{char, item, bufnr})
              end
            }
          },
          -- Disable for tex
          tex = false
        }
      })
    )


    npairs.add_rules({
        Rule("begin$", " end", "julia")
          :use_regex(true)
    })
  '';
}
