#!/bin/bash

SYSTEMS=("butler" "reckless" "daly" "chesty" "webb")

echo "stages:"
echo "  - build"

for SYSTEM in "${SYSTEMS[@]}"
do
  echo "
build-$SYSTEM:
  stage: build
  variables:
    SYSTEM: \"$SYSTEM\"
  tags:
    - nix
  only:
    - nixos
  script:
    - nix build .#nixosConfigurations.\$SYSTEM.config.system.build.toplevel -j 1;
    - attic push campground ./result
  needs:
    - update-flake"
done
