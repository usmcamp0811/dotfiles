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

local function parse_test_output(results)
  out = {}
  failed_tests = {}
  summary_tests = {}
  -- {name = "tst-name", lvl = 2, total = 3, fail = 1, pass = 2}
  res = {}
  cols = {}
  if results then
    summary = 0
    -- for each line in results
    for i in pairs(results) do
      -- if the line is a failed test
      if string.find(results[i], "Test Failed") then
        test_name = split(results[i],":")[1]

        if summary_tests[test_name] == nil then
          summary_tests[test_name] = {
            name = test_name,
            fail = 1
          }
        else
          summary_tests[test_name] = {
            name = test_name,
            fail = summary_tests[test_name][fail]
          }
        end
        
      elseif string.find(results[i], "Test Summary:") then -- if the line is summary line
        skip = true
      elseif string.find(results[i], " | ") then
        r = split(results[i],"|")
        -- shouldn't have gotten to these unless we've been told what failed already so...
        current_test = r[1] 
        _, lvl, _x = string.find(r[1], '^(%s*)') -- count the number of leading spaces.. this is used for grouping and count passes
        rr = string.reverse(r[2]) -- put things in zulu order to make it easier to index
        time = split(rr, " ")[1]
        rrr = rr:gsub(time, " ") -- just poping the time out to get at the totals
        -- we are going in zulu order so the first match is the totals column
        for c in string.gmatch(rrr, "%S+") do
          total = c
          break
        end
        -- check if we have seen the test.. if not make the table for it
        if summary_tests[current_test] == nil then
          summary_tests[current_test] = {
            name = current_test,
            fail = 0,
            total = total,
            lvl = lvl
          }
        else -- we have seen this test in a failed state just add the total tests in it... we counted fails earlier
          summary_tests[current_test]["total"] = total
          summary_tests[current_test]["lvl"] = lvl
        end
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {lvl.."-"..current_test..": total - "..total.." pass - "})
      end
          -- table.insert(out, results[i])
    end
    return col
  end
end


vim.fn.jobstart({"julia", runtests_jl},
  {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
        results = parse_test_output(data)
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, results)
        -- for line in data do
        --   print(vim.inspect(line))
        -- end
      end
    end,
    -- on_stderr = function(_, data)
    --   if data then
    --       vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    --   end
    -- end
  })
