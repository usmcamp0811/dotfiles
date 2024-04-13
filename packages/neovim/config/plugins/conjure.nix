{pkgs, ...}: {
  plugins = {conjure.enable = true;};
  extraConfigLua = ''
    --[[ -- local function file_exists(name) ]]
    --    local f=io.open(name,"r")
    --    if f~=nil then io.close(f) return true else return false end
    -- end
    --
    -- -- looks for the Project.toml to use for the test
    -- local function julia_project_dir()
    --   bufnr = vim.fn.bufnr('%')
    --   -- ns_id = vim.api.nvim_create_namespace('julia-testing')
    --   local root_dir
    --   for dir in vim.fs.parents(vim.api.nvim_buf_get_name(bufnr)) do
    --     if file_exists(dir .. "/Project.toml") == true then
    --       root_dir = dir
    --       break
    --     end
    --   end
    --
    --   if root_dir then
    --     -- print("Found julia project at", root_dir)
    --     return root_dir
    --   end
    -- end
    --
    --
    -- local function make_conjure_command()
    -- 	local root = julia_project_dir()
    -- 	if root == nil then
    -- 		root = ""
    --   else
    --     root = "--project=" .. root
    -- 	end
    -- 	-- vim.g["conjure#client#julia#stdio#command"] = "julia --banner=no --color=no --project=" .. root
    -- 	-- vim.g["conjure#client#julia#stdio#command"] = "julia -i ".. root
    -- 	-- vim.g["conjure#client#julia#stdio#command"] = "jupyter console --kernel julia-1.8 -f /tmp/julia.json"
    -- end
    vim.g["conjure#filetypes"] = { "fennel", "clojure" }
    vim.g['conjure#extract#tree_sitter#enabled'] = true
  '';
}
