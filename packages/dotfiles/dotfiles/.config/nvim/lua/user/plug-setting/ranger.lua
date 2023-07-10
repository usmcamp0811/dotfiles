
-- Make Ranger rep ace Netrw and be the file explorer
vim.g.rnvimr_enable_ex = 1

-- Make Ranger to be hidden after picking a file
vim.g.rnvimr_enable_picker = 1

-- Disable a border for floating window
vim.g.rnvimr_draw_border = 0

-- Hide the files included in gitignore
vim.g.rnvimr_hide_gitignore = 1

-- Change the border's color
vim.g.rnvimr_border_attr = {
  fg = 14,
  bg = -1
}

-- Make Neovim wipe the buffers corresponding to the files deleted by Ranger
vim.g.rnvimr_enable_bw = 1

-- Add a shadow window, value is equal to 100 will disable shadow
vim.g.rnvimr_shadow_winblend = 70

-- Draw border with both
vim.g.rnvimr_ranger_cmd = { 'ranger', '--cmd=set draw_borders both' }

-- Link CursorLine into RnvimrNormal highlight in the Floating window
vim.cmd "highlight link RnvimrNormal CursorLine"


-- Map Rnvimr action
vim.g.rnvimr_action = {
  ['<C-t>'] = 'NvimEdit tabedit',
  ['<C-x>'] = 'NvimEdit split',
  ['<C-v>'] = 'NvimEdit vsplit',
  ['gw'] = 'JumpNvimCwd',
  ['yw'] = 'EmitRangerCwd'
}

-- Add views for Ranger to adapt the size of floating window
vim.g.rnvimr_ranger_views = {
  {
    minwidth = 90,
    ratio = {}
  },
  {
    minwidth = 50,
    maxwidth = 89,
    ratio = {1,1}
  },
  {
    maxwidth = 49,
    ratio = {1}
  }
}

vim.cmd[[ 
  " Customize the initial layout
  let g:rnvimr_layout = {
              \ 'relative': 'editor',
              \ 'width': float2nr(round(0.7 * &columns)),
              \ 'height': float2nr(round(0.7 * &lines)),
              \ 'col': float2nr(round(0.15 * &columns)),
              \ 'row': float2nr(round(0.15 * &lines)),
              \ 'style': 'minimal'
              \ }
]]

-- Customize multiple preset layouts
-- '{}' represents the initial layout
vim.g.rnvimr_presets = {
  {
    width = 0.600,
    height = 0.600
  },
  { width = 0.800,
    height = 0.800
  },
  {
    width = 0.950,
    height = 0.950
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0,
    row = 0
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0,
    row = 0.5
   },
  {
    width = 0.500,
    height = 0.500,
    col = 0.5,
    row = 0
  },
  {
    width = 0.500,
    height = 0.500,
    col = 0.5,
    row =  0.5
   },
  {
    width = 0.500,
    height = 1.000,
    col = 0,
    row = 0
  },
  {
    width = 0.500,
    height = 1.000,
    col = 0.5,
    row = 0
  },
  {
    width = 1.000,
    height = 0.500,
    col = 0,
    row = 0
  },
  {
    width = 1.000,
    height = 0.500,
    col = 0,
    row = 0.5
  }
}

-- Fullscreen for initial layout
-- let g:rnvimr_layout = {
--            \ relative = editor =
--            \ width = &columns,
--            \ height = &lines - 2,
--            \ col = 0,
--            \ row = 0,
--            \ 'style': 'minimal'
--            \ }
--
-- Only use initial preset layout
-- let g:rnvimr_presets = [{}]
-- nmap <space>r :RnvimrToggle<CR>
vim.g.rnvimr_vanilla = 1
