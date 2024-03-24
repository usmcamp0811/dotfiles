# Campground NeoVim Configuration in Nix

This repository hosts my NeoVim configuration, which is currently being transitioned from Lua to Nix. While the configuration is mostly functional, some features are still under development or may contain bugs.

## Getting Started

To use this configuration, follow the steps below:

### Installing Nix (If Not Installed)
```sh
sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
curl -L https://nixos.org/nix/install | sh
source /home/$USER/.nix-profile/etc/profile.d/nix.sh
```

### Running the Configuration
```sh
nix run gitlab:usmcamp0811/campground-nvim
```

## Features Checklist

- [ ] **Base Settings**
- [ ] **LSP**
  - [ ] Configs
  - [ ] Handlers
  - [ ] Null-LS
  - [ ] Mason
    - [ ] Julia
    - [ ] Python
    - [ ] Clojure
    - [ ] Lua
- [ ] **Plugins**
  - [ ] Vim Enhancements
    - [x] Toggle Term
    - [x] hlsens
    - [ ] nvim-tree
    - [ ] pretty-fold
    - [x] autosave
    - [x] ranger
    - [ ] impatient
    - [x] whichkey
  - [ ] Organization
    - [x] Neorg
    - [ ] Vimwiki
    - [ ] Literate
    - [ ] Zen
    - [ ] Mind
    - [ ] Pandoc
    - [ ] Markdown
    - [x] knap
    - [ ] project
    - [ ] Calendar
  - [ ] Coding
    - [ ] Conjure
    - [ ] Comment
    - [ ] Code Window
    - [ ] Navic
  - [x] Git
  - [ ] Treesitter & LSP
    - [ ] Treesitter
  - [ ] Telescope
  - [x] Autocomplete
    - [x] cmp
    - [x] Auto Pairs
  - [x] Movement
    - [x] Leap
  - [ ] Visuals
    - [x] Alpha
    - [x] lualine
    - [ ] bufferline
    - [x] scrollbars
    - [x] colorizer
    - [x] Current Theme (ayu)
- [ ] **Snippets**
- [ ] **Key Maps**
  - [ ] Normal Mode
  - [ ] Visual Mode
  - [ ] Insert Mode
