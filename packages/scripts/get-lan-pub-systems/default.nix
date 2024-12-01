{
  inputs,
  lib,
  writeShellApplication,
  pkgs,
  ...
}:
writeShellApplication {
  name = "get-lan-pub-systems";
  meta = {mainProgram = "get-lan-pub-systems";};
  text = ''
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

    ${pkgs.nix}/bin/nix eval --json '.#nixosConfigurations' --apply "
      configurations: (builtins.filter (name:
        configurations.\''${name}$ENABLED_PATH == true
      ) (builtins.attrNames configurations))
    " | ${pkgs.jq}/bin/jq -r '.[]'
  '';
}
