local bufnr = 9
local runtests_jl = "/home/mcamp/.config/nvim/lua/user/julia-tests/runtests.jl"

--todo remove this split function and replace with vim.split
local function split(str, delimiter)
	assert(type(delimiter) == "string")
	assert(#delimiter > 0, "Must provide non empty delimiter")

	-- Add escape characters if delimiter requires it
	delimiter = delimiter:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")

	local start_index = 1
	local result = {}

	while true do
		local delimiter_index, _ = str:find(delimiter, start_index)

		if delimiter_index == nil then
			table.insert(result, str:sub(start_index))
			break
		end

		table.insert(result, str:sub(start_index, delimiter_index - 1))

		start_index = delimiter_index + 1
	end

	return result
end

-- will return array of length of 3 or 2. The last record will always be total
local function calc_pass_fail_total(line)
    pft = {}
    for v in string.gmatch(current_line, "(%s%d+%s)") do
        table.insert(pft, v)
    end
    if #pft == 3 then
        return {
            pass = pft[1],
            fail = pft[2],
            total = pft[3],
            missing = false,
            failed_lines = {},
        }
    else
        return {
            pass = "0",
            fail = "0",
            total = pft[#pft],
            missing = "true",
            failed_lines = {},
        }
    end
end

local function rtrim(s)
	return s:match("^(.*%S)%s*$")
end

local function ltrim(s)
	return s:match("^%s*(.*)")
end

local function check_results(res)
	for t in pairs(res) do
		pf = res[t].pass + res[t].fail
		go = pf == tonumber(res[t].total)
		if go then
			res[t].missing = "false"
		else
			error("Test results => ".."Name: "..t.. " Pass: "..res[t].pass.." Fail: "..res[t].fail.. " Total: "..res[t].total, 2)
		end
	end
end

local function updated_failed_test(test_res, line)
  table.insert(test_res.failed_lines, line)
  if tonumber(test_res.fail) + tonumber(test_res.pass) ~= tonumber(test_res.total) then
    -- check if these  dont equal maybe we failed all the tests
    test_res.fail = tostring(tonumber(test_res.fail) + 1)
  elseif
    tonumber(test_res.fail) + tonumber(test_res.pass) == tonumber(test_res.total) then
    test_res.missing = "false"
  end
  return test_res
end


local function parse_test_results(results)
	res = {}
	-- res["name"] = {pass = 1, fail = 1, total = 2, missing = false}
	need_pass_calc = {}
	if results then
		for i = 1, #results do
			current_line = results[#results + 1 - i]
			if string.find(current_line, "|") then
				if string.find(current_line, "Test Summary:") then
					skip = true
				else
					test_name = ltrim(rtrim(split(current_line, " | ")[1]))
					res[test_name] = calc_pass_fail_total(current_line)
				end
			elseif string.find(current_line, "Test Failed") then
        split_line = vim.split(current_line, ":")
				-- test_name = ltrim(rtrim(split(current_line, ":")[1]))
        test_name = ltrim(rtrim(split_line[1]))
        fail_line = ltrim(rtrim(split_line[3]))
        res[test_name] = updated_failed_test(res[test_name], fail_line)
			end
		end
	end
  print(vim.inspect(res))
	check_results(res)

	return res
end

local function get_testset_line_number(test_name)
	bufftype = vim.bo.filetype
	language_tree = vim.treesitter.get_parser(bufnr, bufftype)
	syntax_tree = language_tree:parse()
	root = syntax_tree[1]:root()
  query = "(macro_expression (macro_argument_list (string_literal) @name (#match? @name \"" .. test_name .. "\"))  @ml )"
	pq = vim.treesitter.parse_query("julia", query)
	for id, node, metadata in pq:iter_captures(root, bufnr, 0, vim.fn.line('$')) do
    -- there should only be one match
    -- row1, col1, row2, col2 = node:range()
    return node:range()
	end
end


-- vim.api.nvim_create_autocmd("BufWritePost", {
--   group = vim.api.nvim_create_augroup("julia-autotest", {clear = true}),
--   pattern = "runtests.jl",
--   callback = function(_, data)
--     if data then
--       line_nr = 1
--       vim.api.nvim_buf_set_extmark(bufnr, 4, line_nr, 0, { virt_text = { "Hello World!"}})
--     end
--   end
-- })


vim.api.nvim_create_user_command("AutoTest", function()
  print("We are running tests now")
  bufnr = vim.fn.bufnr('%') 
  ns_id = vim.api.nvim_create_namespace('julia-testing')

  runtests = vim.fn.expand('%:p') 
  print("On: ".. runtests)
  vim.fn.jobstart({ "julia", runtests }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
        test_results = parse_test_results(data)
        id = 1
        for test_name in pairs(test_results) do
          test = test_results[test_name]
          line_num, col_num, _, j = get_testset_line_number(test_name)
          -- line_num = 23
          -- col_num = 1
          opts = {
            end_line = 10,
            id = id,
            virt_text = {{"<-Tested", "IncSearch"}},
            virt_text_pos = 'eol',
            -- virt_text_win_col = 20,
          }

          mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num, col_num, opts)
          failed_tests = test.failed_lines
          if #failed_tests > 0 then
            for ix, f in ipairs(failed_tests) do
              id = id + 1
              fline = tonumber(test.failed_lines[ix]) - 1
              opts = {
                end_line = 10,
                id = id,
                virt_text = {{"<-This Failed", "IncSearch"}},
                virt_text_pos = 'eol',
                -- virt_text_win_col = 20,
              }
              mark_id2 = vim.api.nvim_buf_set_extmark(bufnr, ns_id, fline, j, opts)
            end
          end
          id = id + 1
        end
      end
    end,
  })
end, {})
