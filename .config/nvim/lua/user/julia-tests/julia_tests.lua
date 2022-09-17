local bufnr = 9
local runtests_jl = "/home/mcamp/.config/nvim/lua/user/julia-tests/runtests.jl"

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
        }
    else
        return {
            pass = "0",
            fail = "0",
            total = pft[#pft],
            missing = "true",
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

local function updated_failed_test(test_res)
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
				test_name = ltrim(rtrim(split(current_line, ":")[1]))
        res[test_name] = updated_failed_test(res[test_name])
			end
		end
	end
	check_results(res)
	return res
end

local function get_testset_line_number(test_name)
  query = "(macro_expression (macro_argument_list (string_literal) @name (#eq? @name \"length test\")))"
	pq = vim.treesitter.parse_query("julia", query)
end

function get_julia_test_file()

end

require("project_nvim.project")

print(get_project_root())


vim.api.nvim_create_user_command("AutoTest", function()
  print("We are running tests now")
  bufnr = vim.nvim_get_current_buf
  runtests = vim.fn.expand('%:p') 
  vim.fn.jobstart({ "julia", runtests }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
        test_results = parse_test_results(data)
        for v in pairs(test_results) do
          test = test_results[v]
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
            "Match test -> "
              .. tostring(v)
              .. "  Failed: "
              .. tostring(test.fail)
              .. " Pass: "
              .. tostring(test.pass)
              .. " Total: "
              .. tostring(test.total),
          })
          -- 	-- vim.api.nvim_buf_set_extmark(bufnr,ns )
        end
      end
    end,
  })
end, {})
