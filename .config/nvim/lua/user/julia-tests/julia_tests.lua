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
	for v in string.gmatch(current_line, "(%s%d+)") do
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

function rtrim(s)
	return s:match("^(.*%S)%s*$")
end

function ltrim(s)
	return s:match("^%s*(.*)")
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

local function check_results(res)
	for t in pairs(res) do
		pf = res[t].pass + res[t].fail
		go = pf == tonumber(res[t].total)
		if go then
			res[t].missing = false
		else
			error("Test results don't add up.. might be missing one.", 2)
		end
	end
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
					if res[test_name]["missing"] == true then
						-- if we are here we need to go further and see if everything failed or everything passed
						table.insert(need_pass_calc, test_name)
					end
				end
			elseif string.find(current_line, "Test Failed") then
				test_name = ltrim(rtrim(split(current_line, ":")[1]))
				-- check if these  dont equal maybe we failed all the tests
				if tonumber(res[test_name].fail) + tonumber(res[test_name].pass) ~= tonumber(res[test_name].total) then
					res[test_name]["fail"] = tostring(tonumber(res[test_name]["fail"]) + 1)
				elseif
					tonumber(res[test_name]["fail"]) + tonumber(res[test_name]["pass"])
					== tonumber(res[test_name]["total"])
				then
					res[test_name]["missing"] = "false"
				end
			end
		end
	end
	check_results(res)
	return res
end

-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {lvl.."-"..current_test..": total - "..total.." pass - "})

vim.fn.jobstart({ "julia", runtests_jl }, {
	stdout_buffered = true,
	on_stdout = function(_, data)
		if data then
			-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
			test_results = parse_test_results(data)
			for v in pairs(results) do
				test = test_results[v]
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
					"Match test -> "
						.. v
						.. "  Failed: "
						.. test.fail
						.. " Pass: "
						.. test.pass
						.. " Total: "
						.. test.total,
				})
				-- 	-- vim.api.nvim_buf_set_extmark(bufnr,ns )
			end
		end
	end,
	-- on_stderr = function(_, data)
	--   if data then
	--       vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
	--   end
	-- end
})

--TS Query for testsets names
-- (macro_expression (macro_argument_list (string_literal) @name))
