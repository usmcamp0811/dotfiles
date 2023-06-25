for file in ~/.config/shell/zsh/*.zsh; do
    [ -r "$file" ] && source "$file"
done

# source all the other bash config files
for file in ~/.config/shell/*.shrc; do
    [ -r "$file" ] && source "$file"
done

for file in ~/.config/shell/private/*.shrc; do
    [ -r "$file" ] && source "$file"
done

source $HOME/.config/shell/zsh/theme

eval "$(direnv hook zsh)"
