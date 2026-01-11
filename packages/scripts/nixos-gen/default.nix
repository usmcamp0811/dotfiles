{pkgs}:
pkgs.writeShellScriptBin "nixos-gen-fzf" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    PATH="${pkgs.lib.makeBinPath [
    pkgs.fzf
    pkgs.nix
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gawk
    pkgs.util-linux
  ]}:$PATH"

    profile="/nix/var/nix/profiles/system"

    usage() {
      cat <<'EOF'
  Usage:
    nixos-gen-fzf [--boot|--switch|--test] [--reboot] [--no-sudo]

  What it does:
    - Shows NixOS system generations in fzf
    - Lets you pick one
    - Activates it via switch-to-configuration

  Modes:
    --boot    Set it for next boot (default)
    --switch  Switch immediately (like nixos-rebuild switch)
    --test    Activate temporarily (like nixos-rebuild test)

  Other flags:
    --reboot  Reboot after activating
    --no-sudo Assume you're already root; don't use sudo
  EOF
    }

    mode="boot"
    reboot="0"
    use_sudo="1"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --boot) mode="boot"; shift ;;
        --switch) mode="switch"; shift ;;
        --test) mode="test"; shift ;;
        --reboot) reboot="1"; shift ;;
        --no-sudo) use_sudo="0"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
      esac
    done

    # Choose sudo strategy
    run_as_root() {
      if [[ "$use_sudo" == "1" && "$(id -u)" -ne 0 ]]; then
        sudo "$@"
      else
        "$@"
      fi
    }

    if [[ ! -e "$profile" ]]; then
      echo "Expected profile at: $profile (not found)" >&2
      exit 1
    fi

    # Build generation list (keep the full nix-env output for display)
    gens="$(run_as_root nix-env -p "$profile" --list-generations || true)"
    if [[ -z "''${gens//[[:space:]]/}" ]]; then
      echo "No generations found from: nix-env -p $profile --list-generations" >&2
      exit 1
    fi

    # Pick one line, then parse the generation number (first field)
    selection="$(
      printf '%s\n' "$gens" | fzf \
        --prompt="NixOS generation> " \
        --height=80% \
        --layout=reverse \
        --border \
        --preview-window="right:60%:wrap" \
        --preview='
          set -euo pipefail
          gen="$(echo {} | awk "{print \$1}")"
          link="/nix/var/nix/profiles/system-${gen}-link"
          if [[ -e "$link" ]]; then
            echo "Link: $link"
            echo "Store: $(readlink -f "$link")"
            echo
            if [[ -x "$link/bin/nixos-version" ]]; then
              echo -n "nixos-version: "
              "$link/bin/nixos-version" || true
            fi
            if [[ -x "$link/sw/bin/nix" ]]; then
              echo
              echo "Top-level closure:"
              "$link/sw/bin/nix" path-info -S "$link" 2>/dev/null | head -n 20 || true
            fi
          else
            echo "Missing: $link"
          fi
        '
    )"

    if [[ -z "$selection" ]]; then
      echo "No selection made." >&2
      exit 1
    fi

    gen="$(printf '%s\n' "$selection" | awk '{print $1}')"
    link="/nix/var/nix/profiles/system-${gen}-link"

    if [[ ! -e "$link" ]]; then
      echo "Selected generation link does not exist: $link" >&2
      exit 1
    fi

    echo "Selected generation: $gen"
    echo "Mode: $mode"
    echo

    # 1) Switch the system profile pointer to that generation
    run_as_root nix-env -p "$profile" --switch-generation "$gen"

    # 2) Activate it (boot/switch/test)
    if [[ -x "$link/bin/switch-to-configuration" ]]; then
      run_as_root "$link/bin/switch-to-configuration" "$mode"
    else
      echo "Missing switch-to-configuration at: $link/bin/switch-to-configuration" >&2
      exit 1
    fi

    if [[ "$reboot" == "1" ]]; then
      echo
      echo "Rebooting..."
      run_as_root systemctl reboot
    else
      echo
      echo "Done."
      if [[ "$mode" == "boot" ]]; then
        echo "Activated for next boot. Reboot when ready."
      fi
    fi
''
