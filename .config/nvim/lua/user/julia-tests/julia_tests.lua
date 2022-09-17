local bufnr = 9
local runtests_jl = "/home/mcamp/.config/nvim/lua/user/julia-tests/runtests.jl"
-- local runtests_jl = "/home/mcamp/code/level-up/julia/test"
-- local test_file = vim.fn.expand('%:p')
-- path, file = string.match(runtests_jl, "(.-)([^\\/]-%.?([^%.\\/]*))$")
-- path = path:sub(1, -2)
-- project_path, _ = string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$") 

-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {project_path, file})


-- function trim(s)
--     return s:match'^%s*(.*%S)' or ''
-- end
-- function split(s, delimiter)
--     result = {};
--     for match in (s..delimiter):gmatch("(.-)"..delimiter) do
--         table.insert(result, match);
--     end
--     return result;
-- end
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
-- local function parse_header(header)
--   cols = {}
--
--   h_array = split(header, "|")
--   title = h_array[1]
--   cols = split(h_array[2], " ")
-- end

-- will return array of length of 3 or 2. The last record will always be total
local function calc_pass_fail_total(line)
  pft = {}
  for i in string.gmatch(current_line, "(%s%d+%s)") do
    table.insert(pft, i)
  end
  if #pft == 3 then
    return {pass=pft[1], fail=pft[2], total=pft[3], missing=false}
  else
    return {total=pft[#pft], missing=true}
  end
end

function rtrim(s)
  return s:match'^(.*%S)%s*$'
end

local function parse_test_results2(results)
  res = {}
--   -- {name = "tst-name", lvl = 2, total = 3, fail = 1, pass = 2}
  fail_check = {}
  if results then
    for i=1, #results do
      current_line = results[#results + 1 - i]
      if string.find(current_line, "|") then
        test_name = rtrim(split(current_line," | ")[1])
        res[test_name] = calc_pass_fail_total(line)
        if res[test_name]["missing"] == true then
          -- if we are here we need to go further and see if everything failed or everything passed
          table.insert(fail_check, test_name)
        end
      end
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, tbl)
end

-- local function parse_test_output(results)
--   -- {name = "tst-name", lvl = 2, total = 3, fail = 1, pass = 2}
--   if results then
--     vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {results[#results-2]})
--     summary_tests = {}
--     j = 0
--     -- for each line in results
--     for i in pairs(results) do
--       -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"^^^^^"})
--       -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {results[i]})
--       -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Missing->"..results[i]})
--       -- if the line is a failed test
--       if string.find(results[i], "Test Failed") then
--         j = j + 1
--         test_name = split(results[i],":")[1]
--         if summary_tests[test_name] == nil then
--           summary_tests[test_name] = {
--             name = test_name,
--             fail = 1,
--             pass = -1,
--             total = -1,
--             lvl = -1,
--             index = j
--           }
--         else
--         j = j + 1
--           summary_tests[test_name] = {
--             name = test_name,
--             fail = summary_tests[test_name][fail],
--             pass = -1,
--             total = -1,
--             lvl = -1,
--             index = j
--           }
--         end
--       elseif string.find(results[i], "Test Summary:") then -- if the line is summary line
--         skip = true
--         j = j + 1
--       elseif string.find(results[i], "|") then
--         -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Missing->"..results[i]})
--         j = j + 1
--         r = split(results[i],"|")
--         -- shouldn't have gotten to these unless we've been told what failed already so...
--         current_test = r[1] 
--         _, lvl, _x = string.find(r[1], '^(%s*)') -- count the number of leading spaces.. this is used for grouping and count passes
--         rr = string.reverse(r[2]) -- put things in zulu order to make it easier to index
--         time = split(rr, " ")[1]
--         rrr = rr:gsub(time, " ") -- just poping the time out to get at the totals
--         -- we are going in zulu order so the first match is the totals column
--         for c in string.gmatch(rrr, "%S+") do
--           total = c
--           break
--         end
--         -- check if we have seen the test.. if not make the table for it
--         if summary_tests[current_test] == nil then
--           summary_tests[current_test] = {
--             name = current_test,
--             fail = 0,
--             total = total,
--             lvl = lvl,
--             index = j
--           }
--         else -- we have seen this test in a failed state just add the total tests in it... we counted fails earlier
--           summary_tests[current_test]["total"] = total
--           summary_tests[current_test]["lvl"] = lvl
--           summary_tests[current_test]["index"] = j
--         end
--         -- print(#summary_tests)
--         return summary_tests
--       end
--     end
--   -- else
--     -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Missing->"..results[i]})
--   end
-- end

        -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {lvl.."-"..current_test..": total - "..total.." pass - "})

vim.fn.jobstart({"julia", runtests_jl},
  {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
        results = parse_test_results2(data)
        -- for i, v in pairs(results) do
          -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Match test -> "..v.name.."  Failed: "..v.fail.." Total: "..v.total})
          -- vim.api.nvim_buf_set_extmark(bufnr,ns )
        -- end
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
