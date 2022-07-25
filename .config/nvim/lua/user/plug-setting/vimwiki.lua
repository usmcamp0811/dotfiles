
vim.cmd "autocmd BufRead,BufNewFile *.wiki set filetype=vimwik"
-- vim.cmd "autocmd BufRead,BufNewFile diary.md :CalendarVR"
vim.cmd "autocmd BufReadPre diary.md :VimwikiDiaryGenerateLinks"

vim.g.vimwiki_ext2syntax = {
  [".Rmd"] = "markdown",
  [".rmd"] = "markdown",
  [".markdown"] = "markdown",
  [".mdown"] = "markdown"
}
vim.g.vimwiki_list = {
  {
      path = '~/vimwiki',
      syntax = 'markdown',
      ext = '.md',
      auto_toc = 1,
      links_space_char = "_",
      auto_diary_index = 1,
      diary_caption_level = 2,
  },
  {
      path = '~/vimwiki/devops',
      syntax = 'markdown',
      ext = '.md',
      auto_toc = 1,
  },
  {
      path = '~/vimwiki/code',
      syntax = 'markdown',
      ext = '.md',
      auto_toc = 1,
  }


}
vim.g.vim_markdown_math = 1
vim.g.vim_markdown_json_frontmatter = 1
vim.g.vim_markdown_strikethrough = 1
vim.g.vim_markdown_new_list_item_indent = 2
vim.g.vimwiki_global_ext = 0
vim.g.vimwiki_table_mappings = 0
vim.g.vimwiki_listsyms = '✗○◐●✓'
vim.g.vimwiki_use_calendar = 1
vim.g.vimwiki_auto_header = 1

