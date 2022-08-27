require("mind").setup({
	edit = {
		data_extension = ".norg",
		data_header = "* %s",
	},
	persistence = {
		state_path = "~/.wiki/mind.json",
		data_dir = "~/.wiki/",
	},
})
