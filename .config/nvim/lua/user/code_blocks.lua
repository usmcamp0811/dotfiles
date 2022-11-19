local q = require("vim.treesitter.query")
local ts_utils = require("nvim-treesitter.ts_utils")

local queries = {}

queries["norg"] = [[
    (ranged_tag 
      (tag_name) @block (#eq? @block "code")
        (tag_parameters) @lang 
          (ranged_tag_content) @code 
          )
  ]]

-- (fenced_code_block) @block
-- (language) @lang
queries["markdown"] = [[
  ((section) 
    (inline)
    (fenced_code_block)
    )
  ]]

-- todo rename to norg specific or move the query out
local function code_block_under_cursor()
	bufftype = vim.bo.filetype
	language_tree = vim.treesitter.get_parser(bufnr, bufftype)
	syntax_tree = language_tree:parse()
	root = syntax_tree[1]:root()
	query = vim.treesitter.parse_query(bufftype, queries[bufftype])
	-- get current buffer and line under the cursor
	bufnr = vim.api.nvim_get_current_buf()
	current_line, _ = unpack(vim.api.nvim_win_get_cursor(0))
	-- this should ALWAYS be a single loop but  I don't know really how to do this with out a for loop
	-- this is because we are passing `current_line` to `current_line` to the matches function
	-- for _, captures, metadata in query:iter_matches(root, bufnr) do
	for _, captures, metadata in query:iter_matches(root, bufnr, current_line, current_line) do
		lang = q.get_node_text(captures[2], bufnr)
		code = q.get_node_text(captures[3], bufnr)
	end
	return lang, code
end

local function execute(code)
	-- iterate over every line of the code block
	for line in code:gmatch("([^\r\n]*)[\r\n]?") do
		to_send = line == "" and "(blank)" or line
		-- if its blank we need to send the new line command
		if to_send == "(blank)" then
			-- spike: can we use something native and not rely on Slime?
			slime = "\n"
		else
			slime = to_send .. "\n"
		end
		-- runs the line of code
    vim.api.nvim_chan_send(vim.b.slime_config.jobid, slime) 
		-- vim.cmd(slime)
	end
end

local function update_slime_config(lang)
	-- check if we have a repl of the correct language open
	if vim.g[lang .. "_job_id"] == nil then
		print("We dont have a " .. code .. " repl open")
		-- todo: maybe go ahead and open one?
		jobid = nil
		-- do nothing for now
		return nil
	else
		-- set the correct job_id for Slime
		vim.b.slime_config = {
			jobid = vim.g[lang .. "_job_id"],
		}
	end
end

function run_code_block()
	-- todo call the correct query md/norg
	lang, code = code_block_under_cursor()
	-- print(vim.inspect(root), "userdata?")
	-- print(vim.inspect(lang))
	-- print(vim.inspect(code))

	-- fix the cases where a space is on the end of the language
	lang = string.gsub(lang, "%s+", "")
	update_slime_config(lang)
	execute(code)
end

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
