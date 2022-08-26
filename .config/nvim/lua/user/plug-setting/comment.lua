local status_ok, comment = pcall(require, "Comment")
if not status_ok then
  return
end

comment.setup {
  pre_hook = function(ctx)
    local U = require "Comment.utils"

    local location = nil
    if ctx.ctype == U.ctype.block then
      location = require("ts_context_commentstring.utils").get_cursor_location()
    elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
      location = require("ts_context_commentstring.utils").get_visual_start_location()
    end

    return require("ts_context_commentstring.internal").calculate_commentstring {
      key = ctx.ctype == U.ctype.line and "__default" or "__multiline",
      location = location,
    }
  end,
}

local status_still_ok, which_key = pcall(require, "which-key")
if not status_still_ok then
  return
end

which_key.register({
  ["<BS>"] = { "<Plug>(comment_toggle_current_linewise)<cr>", "Comment Toggle" },
  T = { ":r! date +'\\%H:\\%M - '<CR>A", "Insert Current Time"}
})

which_key.register({
  ["<BS>"] = { "<Plug>(comment_toggle_linewise_visual)<cr>", "Comment Toggle" },
  p = { '"_dP', "Paste without overwriting the register" },
}, { mode = "v" })

