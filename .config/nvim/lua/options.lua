o = vim.opt
bo = vim.bo
wo = vim.wo

o.directory = '~/.config/nvim/swaps'
o.backupdir = '~/.config/nvim/backups'
o.undodir = '~/.config/nvim/undo'
o.termguicolors = true
o.clipboard = 'unnamedplus'
o.autoindent = true
o.diffopt = 'filler'
o.cursorline = true
o.mouse = 'a' -- enable mouse in all modes
o.wrap = false -- don't wrp lines
o.magic = true -- Enable extended regex commands
o.joinspaces = false -- Only insert single space after a '.', '?' and '!' with a join command
o.showmode = false -- Going to use airline.vim to handle this for us
o.startofline = false -- Don't reset cursor to the start of the line when moving around
o.ruler = true -- Show current position
o.nu = true -- enable line numbers
o.shell = '/bin/zsh'
o.splitbelow = true -- New windows go below
o.splitright = true -- New windows go right
o.title = true -- Show the filename in the window titlebar
o.undofile = true -- Persistent Undo
o.wildmenu = true -- Hitting TAB in command mode will show possible completion above command line
o.wrapscan = true -- Searches wrap around end of file
o.encoding = 'utf-8' -- nobomb
-- vim.o.guioptions = 'a' -- copy on select... requires gvim
o.shortmess = 'atI' -- Don't show the intro message when starting vim
o.showtabline = 2 -- Always show tab bar
o.sidescrolloff = 3 -- Start scrolling three columns before vertical border of window
o.smartcase = true -- Ignore 'ignorecase' if search patter contains uppercase characters
o.smarttab = true -- At start of line, <Tab> inserts shiftwidth spaces, <Bs> deletes shiftwidth spaces
o.scrolloff = 3 -- Start scrolling three lines before horizontal border of window
o.lazyredraw = true -- Don't redraw when we don't have to
o.laststatus = 2 -- Always show status line
o.spell = true -- turns on spell check
o.relativenumber = true -- Use relative line numbers. Current line is still in status bar.
o.wildignore = {
    '.DS_Store', '*.jpg', '*.jpeg', '*.gif', '*.png', '*.gif', '*.psd', '*.o', '*.obj', '*.min.js',
    '*/bower_components/*', '*/node_modules/*',
    '*/smarty/*', '*/vendor/*', '*/.git/*', '*/.hg/*', 
    '*/.svn/*', '*/.sass-cache/*', '*/log/*', '*/tmp/*', 
    '*/build/*', '*/ckeditor/*', '*/doc/*', '*/source_maps/*', '*/dist/*'
}
o.wildmode = 'longest,list,full'
wo.number = true
bo.expandtab = true
bo.shiftwidth = 4
bo.softtabstop = 4

-- TODO: see if its possible to compine into something better
o.listchars:append({ eol = '¬' })
o.listchars:append({ tab = '>·' })
o.listchars:append({ trail = '~' })
o.listchars:append({ precedes = '<' })
o.listchars:append({ space = '␣' })
o.listchars:append({ extends = '>' })

o.iskeyword:append("-")

