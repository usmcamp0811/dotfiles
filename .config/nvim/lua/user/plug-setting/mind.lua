require("mind").setup({
	edit = {
		data_extension = ".norg",
		data_header = "* %s",
	},
	persistence = {
		state_path = "~/vimwiki/mind.json",
		data_dir = "~/vimwiki",
	},
})
