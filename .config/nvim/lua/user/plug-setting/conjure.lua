
local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- looks for the Project.toml to use for the test
local function julia_project_dir()
  bufnr = vim.fn.bufnr('%')
  -- ns_id = vim.api.nvim_create_namespace('julia-testing')
  local root_dir
  for dir in vim.fs.parents(vim.api.nvim_buf_get_name(bufnr)) do
    if file_exists(dir .. "/Project.toml") == true then
      root_dir = dir
      break
    end
  end

  if root_dir then
    -- print("Found julia project at", root_dir)
    return root_dir
  end
end


local function make_conjure_command()
	local root = julia_project_dir()
	if root == nil then
		root = ""
  else
    root = "--project=" .. root
	end
	-- vim.g["conjure#client#julia#stdio#command"] = "julia --banner=no --color=no --project=" .. root
	vim.g["conjure#client#julia#stdio#command"] = "julia " .. root
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
	pattern = "*.jl",
	callback = make_conjure_command,
})

--					l = { "<cmd>lua vim.b.slime_config = {jobid=vim.g.lua_job_id}<cr>", "Get Lua REPL" },
-- this seems to need something in it or things break when opening lua files
vim.g["conjure#filetypes"] = { "fennel", "clojure", "julia", "jl" }
vim.g["conjure#mapping#doc_word"] = { "?" }
-- vim.g["conjure#client#julia#stdio#prompt_pattern"] = { ";\n"}

-- n ,ecw  {":ConjureEvalCommentWord<CR>:silent! call repeat#set(",ecw", 1)<CR>", ""},
-- n ,ece  {":ConjureEvalCommentCurrentForm<CR>:silent! call repeat#set(",ece", 1)<CR>", ""},
-- n ,ecr  {":ConjureEvalCommentRootForm<CR>:silent! call repeat#set(",ecr", 1)<CR>", ""},
-- n ,e! {":ConjureEvalReplaceForm<CR>:silent! call repeat#set(",e!", 1)<CR>", ""},
-- n ,ee {":ConjureEvalCurrentForm<CR>:silent! call repeat#set(",ee", 1)<CR>", ""},
-- n ,ei {":ConjureJuliaInterrupt<CR>:silent! call repeat#set(",ei", 1)<CR>", ""},
-- n ,er {":ConjureEvalRootForm<CR>:silent! call repeat#set(",er", 1)<CR>", ""},
-- n ,ew {":ConjureEvalWord<CR>:silent! call repeat#set(",ew", 1)<CR>", ""},
-- n ,ef {":ConjureEvalFile<CR>:silent! call repeat#set(",ef", 1)<CR>", ""},
-- n ,eb {":ConjureEvalBuf<CR>:silent! call repeat#set(",eb", 1)<CR>", ""},
-- n ,em :ConjureEvalMarkedForm<CR
-- n , {"<Cmd>lua require("which-key").show(",", {mode = "n", auto = true})<CR>", ""},
-- n ,lq {":ConjureLogCloseVisible<CR>:silent! call repeat#set(",lq", 1)<CR>", ""},
-- n ,ll {":ConjureLogJumpToLatest<CR>:silent! call repeat#set(",ll", 1)<CR>", ""},
-- n ,lr {":ConjureLogResetSoft<CR>:silent! call repeat#set(",lr", 1)<CR>", ""},
-- n ,lR {":ConjureLogResetHard<CR>:silent! call repeat#set(",lR", 1)<CR>", ""},
-- n ,lv {":ConjureLogVSplit<CR>:silent! call repeat#set(",lv", 1)<CR>", ""},
-- n ,lg {":ConjureLogToggle<CR>:silent! call repeat#set(",lg", 1)<CR>", ""},
-- n ,lt {":ConjureLogTab<CR>:silent! call repeat#set(",lt", 1)<CR>", ""},
-- n ,le {":ConjureLogBuf<CR>:silent! call repeat#set(",le", 1)<CR>", ""},
-- n ,cs {":ConjureJuliaStart<CR>:silent! call repeat#set(",cs", 1)<CR>", ""},
-- n ,cS {":ConjureJuliaStop<CR>:silent! call repeat#set(",cS", 1)<CR>", ""},
-- n ,gd {":ConjureDefWord<CR>:silent! call repeat#set(",gd", 1)<CR>", ""},
-- n ,E  {"{":set opfunc=ConjureEvalMotion<CR>", ""},g@
--
-- v ,E  {":ConjureEvalVisual<CR>:silent! call repeat#set(",E", 1)<CR>", ""},

