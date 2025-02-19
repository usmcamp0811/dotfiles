#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-hostname>"
    exit 1
fi

TARGET_HOST="$1"
NIXOS_DIR="/config"

cd "$NIXOS_DIR"
deploy --hostname "$TARGET_HOST" --skip-checks .#"$TARGET_HOST"

nvd diff /run/current-system result

read -p "Upgrade? (Y/n): "
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Upgrade aborted."
    exit 1
fi

deploy--hostname "$TARGET_HOST" --skip-checks .#"$TARGET_HOST" --activate
