
local options = {

    foldmethod = "syntax",
    directory = vim.fn.stdpath('config') .. '/swaps',
    backupdir = vim.fn.stdpath('config') .. '/backups',
    undodir = vim.fn.stdpath('config') .. '/undo',
    guifont = "monospace:h17",               -- the font used in graphical neovim applications
    completeopt = { "menuone", "noselect" }, -- mostly just for cmp
    termguicolors = true,
    clipboard = 'unnamedplus',
    autoindent = true,
    diffopt = 'filler',
    cursorline = true,
    mouse = 'a', -- enable mouse in all modes
    wrap = false, -- don't wrp lines
    magic = true, -- Enable extended regex commands
    joinspaces = false, -- Only insert single space after a '.', '?' and '!' with a join command
    showmode = false, -- Going to use airline.vim to handle this for us
    startofline = false, -- Don't reset cursor to the start of the line when moving around
    ruler = true, -- Show current position
    nu = true, -- enable line numbers
    shell = '/bin/zsh',
    splitbelow = true, -- New windows go below
    splitright = true, -- New windows go right
    title = true, -- Show the filename in the window titlebar
    undofile = true, -- Persistent Undo
    wildmenu = true, -- Hitting TAB in command mode will show possible completion above command line
    wrapscan = true, -- Searches wrap around end of file
    encoding = 'utf-8', -- nobomb
    fileencoding= "utf-8",
    -- vim.o.guioptions = 'a' -- copy on select... requires gvim
    shortmess = 'atI', -- Don't show the intro message when starting vim
    showtabline = 2, -- Always show tab bar
    sidescrolloff = 3, -- Start scrolling three columns before vertical border of window
    smartcase = true, -- Ignore 'ignorecase' if search patter contains uppercase characters
    smarttab = true, -- At start of line, <Tab> inserts shiftwidth spaces, <Bs> deletes shiftwidth spaces
    scrolloff = 3, -- Start scrolling three lines before horizontal border of window
    lazyredraw = true, -- Don't redraw when we don't have to
    laststatus = 2, -- Always show status line
    spell = true, -- turns on spell check
    relativenumber = true, -- Use relative line numbers. Current line is still in status bar.
    wildignore = {
        '.DS_Store', '*.jpg', '*.jpeg', '*.gif', '*.png', '*.gif', '*.psd', '*.o', '*.obj', '*.min.js',
        '*/bower_components/*', '*/node_modules/*',
        '*/smarty/*', '*/vendor/*', '*/.git/*', '*/.hg/*', 
        '*/.svn/*', '*/.sass-cache/*', '*/log/*', '*/tmp/*', 
        '*/build/*', '*/ckeditor/*', '*/doc/*', '*/source_maps/*', '*/dist/*'
    },
    wildmode = 'longest,list,full',

}


for k, v in pairs(options) do
  vim.opt[k] = v
end

-- TODO: see if its possible to combine into something better
o = vim.opt
wo = vim.wo
bo = vim.bo

o.listchars:append({ eol = '¬' })
o.listchars:append({ tab = '>·' })
o.listchars:append({ trail = '~' })
o.listchars:append({ precedes = '<' })
o.listchars:append({ space = '␣' })
o.listchars:append({ extends = '>' })
o.iskeyword:append("-")
o.shortmess:append "c"

wo.number = true
bo.expandtab = true
bo.shiftwidth = 2
bo.softtabstop = 2
bo.tabstop = 2
vim.cmd "set expandtab ts=2 sw=2 ai"

