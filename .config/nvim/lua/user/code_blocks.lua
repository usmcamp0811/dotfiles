local q = require"vim.treesitter.query"

-- todo rename to norg specific or move the query out
local function code_block_under_cursor()
  language_tree = vim.treesitter.get_parser(bufnr, 'norg')
  syntax_tree = language_tree:parse()
  root = syntax_tree[1]:root()
  query = vim.treesitter.parse_query('norg', [[
    (ranged_tag 
      (tag_name) @block (#eq? @block "code")
        (tag_parameters) @lang 
          (ranged_tag_content) @code 
          )
  ]])
  -- get current buffer and line under the cursor
  bufnr = vim.api.nvim_get_current_buf()
  current_line, _ = unpack(vim.api.nvim_win_get_cursor(0))
  -- this should ALWAYS be a single loop but  I don't know really how to do this with out a for loop
  -- this is because we are passing `current_line` to `current_line` to the matches function
  for _, captures, metadata in query:iter_matches(root, bufnr, current_line, current_line) do
      lang = q.get_node_text(captures[2], bufnr)
      code = q.get_node_text(captures[3], bufnr)
  end
  return lang, code
end

-- This requires the Slime Plugin and ToggleTerm. 
-- ToggleTerm should be configured so that the `on_open` function will set 
-- vim.g.<lang>_job_id = vim.b.terminal_job_id
-- where <lang> is the name of the language as it would be in `@code <lang>`
-- Slime should be set to use Neovim and disable the prompt
function run_code_block()
  -- todo call the correct query md/norg
  l, code = code_block_under_cursor()
  -- fix the cases where a space is on the end of the language
  lang = string.gsub(l, "%s+", "")
  -- check if we have a repl of the correct language open
  if vim.g[lang.."_job_id"] == nil then 
    print("We dont have a "..lang.." repl open")
    -- todo: maybe go ahead and open one?
    jobid = nil
    -- do nothing for now
    return nil
  else 
    -- set the correct job_id for Slime
    vim.b.slime_config = {
      jobid = vim.g[lang.."_job_id"]
    }
  end
  -- iterate over every line of the code block
  for line in code:gmatch("([^\r\n]*)[\r\n]?") do
    to_send = line == "" and "(blank)" or line
    -- if its blank we need to send the new line command
    if to_send == "(blank)" then
      -- spike: can we use something native and not rely on Slime?
      slime = ':SlimeSend0 "\\n"'
    else
      slime = ":SlimeSend1 "..to_send
    end
    -- runs the line of code
    vim.cmd(slime)
  end
end


-- todo: Create function to send single lines of code to the correct repl


-- These are just some example queries I wanted to save.. maybe get rid of when I am more use to TS
-- (ranged_tag) @code-block 
--   (name: (tag_name) @code-block-def (#eq? @code-block-def "@code julia")

  -- (ranged_tag_content) @code-blocks
  -- ((tag_parameters) @code-lang (#eq? @code-lang "julia"))

-- gets julia code blocks
  -- (ranged_tag 
  --   (tag_name) @block (#eq? @block "code")
  --     (tag_parameters) @lang (#contains? @lang "julia")
  --       (ranged_tag_content) @code 
  --       )

