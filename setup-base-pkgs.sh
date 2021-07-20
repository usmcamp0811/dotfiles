#!/bin/sh

echo "Installing Base Packages from the Arch main repositories"
sudo pacman -S $(curl https://raw.githubusercontent.com/usmcamp0811/dotfiles/wopr/pkglist-base)

echo "Installing Base Packages from AUR"
sudo pacman -S $(curl https://raw.githubusercontent.com/usmcamp0811/dotfiles/wopr/pkglist-aur-base)
