{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  name = "mistral-7b-instruct";

  version = "0.1.Q4_K_M";

  mistral-model = pkgs.fetchurl {
    url =
      "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/raw/main/mistral-7b-instruct-v${version}.gguf";
    sha256 = "sha256-0UK4Qw6ZBhnpS3WK5/gZWlf6Ek7A6lF6I6eV1949UHE=";
  };
in mistral-model╭─mcamp on reckless in /config on master✔️
╰─🚧 git remote -v
origin	git@github.com:usmcamp0811/dotfiles.git (fetch)
origin	git@github.com:usmcamp0811/dotfiles.git (push)
╭─mcamp on reckless in /config on master✔️
╰─🚧 ..
╭─mcamp on reckless in /
╰─ cd config              
╭─mcamp on reckless in /config on master✔️
╰─🚧 la
drwxr-xr-x mcamp users  19 B  Sun Dec  1 08:53:39 2024  .
drwxr-xr-x root  root   27 B  Sat Nov 30 11:07:52 2024  ..
drwxr-xr-x mcamp users  35 B  Sun Dec  1 08:53:39 2024  .config
drwxr-xr-x mcamp users  15 B  Sun Dec  1 08:54:31 2024  .git
drwxr-xr-x mcamp users   3 B  Sun Dec  1 08:53:39 2024  .julia
drwxr-xr-x mcamp users   4 B  Sun Dec  1 08:53:39 2024  .local
drwxr-xr-x mcamp users   7 B  Sun Dec  1 08:53:39 2024 󰉏 Pictures
.rw-r--r-- mcamp users 161 B  Sun Dec  1 08:53:39 2024  .archey3.cfg
.rw-r--r-- mcamp users 2.7 MB Sun Dec  1 08:53:39 2024  .background
.rw-r--r-- mcamp users 150 B  Sun Dec  1 08:53:39 2024 󱆃 .bash_profile
.rw-r--r-- mcamp users 2.0 KB Sun Dec  1 08:53:39 2024 󱆃 .bashrc
.rwxr-xr-x mcamp users  63 B  Sun Dec  1 08:53:39 2024  .fehbg
.rw-r--r-- mcamp users 231 B  Sun Dec  1 08:53:39 2024  .gitconfig
.rw-r--r-- mcamp users 5.0 KB Sun Dec  1 08:53:39 2024  .gitignore
.rw-r--r-- mcamp users  68 B  Sun Dec  1 08:53:39 2024  .npmrc
.rw-r--r-- mcamp users 3.2 KB Sun Dec  1 08:53:39 2024 󱆃 .zshrc
.rw-r--r-- mcamp users 728 B  Sun Dec  1 08:53:39 2024  pkglist-aur.txt
.rw-r--r-- mcamp users 5.2 KB Sun Dec  1 08:53:39 2024  pkglist.txt
.rw-r--r-- mcamp users 3.4 KB Sun Dec  1 08:53:39 2024  README.md
╭─mcamp on reckless in /config on master✔️
╰─🚧 git checkout nixos
error: pathspec 'nixos' did not match any file(s) known to git
╭─mcamp on reckless in /config on master✔️
╰─🚧 
