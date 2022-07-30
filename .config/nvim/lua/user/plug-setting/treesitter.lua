local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
	return
end

parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

parser_configs.markdown = {
  install_info = {
    url = "https://github.com/ikatyang/tree-sitter-markdown",
    files = { "src/parser.c", "src/scanner.cc" },
  },
  filetype = { "vimwiki", "markdown" },
}

configs.setup({
	ensure_installed = "all", -- one of "all" or a list of languages
	ignore_install = { "" }, -- List of parsers to ignore installing
	highlight = {
		enable = true, -- false will disable the whole extension
		disable = { "css" }, -- list of language that will be disabled
    additional_vim_regex_highlighting = {'org'}
	},
	autopairs = {
		enable = true,
	},
	indent = { enable = true, disable = { "python", "css" } },
  parser_configs = parser_configs
})


