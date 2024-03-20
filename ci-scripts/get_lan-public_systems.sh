#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq

# The first argument passed to the script
TYPE="$1"

# Determine the hosting type based on the argument
if [ "$TYPE" = "public" ]; then
  ENABLED_PATH=".config.campground.suites.public-hosting.enable"
elif [ "$TYPE" = "lan" ]; then
  ENABLED_PATH=".config.campground.suites.lan-hosting.enable"
else
  echo "Invalid type: $TYPE"
  exit 1
fi

nix eval --json '.#nixosConfigurations' --apply "
  configurations: (builtins.filter (name: 
    configurations.\${name}$ENABLED_PATH == true
  ) (builtins.attrNames configurations))
" | jq -r '.[]'
