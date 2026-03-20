{ lib, pkgs, config, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.apps.agentic-ai;

  aiPackages = with pkgs; [ antigravity-fhs claude-code ];

  claudeBin = "${pkgs.claude-code}/bin/claude";
  antigravityLauncher = "${pkgs.antigravity-fhs}/bin/antigravity";

  antigravitySandbox = pkgs.writeShellScriptBin "antigravity-sandbox" ''
    set -euo pipefail

    : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR not set}"
    : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY not set}"

    if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "''${XDG_RUNTIME_DIR}/bus" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=''${XDG_RUNTIME_DIR}/bus"
    fi

    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/antigravity-sandbox-home"
    USER_DATA_DIR="$SANDBOX_HOME/.config/Antigravity"
    mkdir -p "$USER_DATA_DIR" "$SANDBOX_HOME"/{.cache,.local/share}

    # Kill any existing antigravity instances so we don't hit Electron singleton weirdness.
    pkill -u "$(id -u)" -f "antigravity" >/dev/null 2>&1 || true

    # Clean common Electron locks (inside sandbox only)
    rm -f "$USER_DATA_DIR"/Singleton{Lock,Cookie,Socket} 2>/dev/null || true

    # Figure out the "real" binary if present, otherwise fall back to launcher.
    launcher_real="$(readlink -f "${antigravityLauncher}" || echo "${antigravityLauncher}")"
    pkg_root="$(dirname "$(dirname "$launcher_real")")"

    real="$launcher_real"
    if [ -x "$pkg_root/lib/antigravity/antigravity" ]; then
      real="$pkg_root/lib/antigravity/antigravity"
    elif [ -x "$pkg_root/libexec/antigravity/antigravity" ]; then
      real="$pkg_root/libexec/antigravity/antigravity"
    fi

    dev_binds=""
    if [ -d /dev/dri ]; then
      dev_binds="$dev_binds --dev-bind /dev/dri /dev/dri"
    fi
    for n in /dev/nvidiactl /dev/nvidia0 /dev/nvidia1 /dev/nvidia-uvm /dev/nvidia-uvm-tools; do
      if [ -e "$n" ]; then
        dev_binds="$dev_binds --dev-bind $n $n"
      fi
    done

    ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-user \
      --unshare-pid \
      --unshare-uts \
      --unshare-cgroup \
      --share-net \
      --die-with-parent \
      --new-session \
      --proc /proc \
      --dev /dev \
      $dev_binds \
      --ro-bind /nix /nix \
      --ro-bind /etc /etc \
      --ro-bind /run/current-system /run/current-system \
      --bind /tmp /tmp \
      --bind "''${XDG_RUNTIME_DIR}" "''${XDG_RUNTIME_DIR}" \
      --bind "$SANDBOX_HOME" "$SANDBOX_HOME" \
      --setenv HOME "$SANDBOX_HOME" \
      --setenv XDG_RUNTIME_DIR "''${XDG_RUNTIME_DIR}" \
      --setenv WAYLAND_DISPLAY "''${WAYLAND_DISPLAY}" \
      --setenv XDG_SESSION_TYPE "wayland" \
      --setenv DBUS_SESSION_BUS_ADDRESS "''${DBUS_SESSION_BUS_ADDRESS:-}" \
      -- "$real" \
        --user-data-dir="$USER_DATA_DIR" \
        --ozone-platform-hint=auto \
        --enable-features=WaylandWindowDecorations \
        --enable-wayland-ime=true \
        --wayland-text-input-version=3 \
        "$@" &

    pid=$!

    # Best-effort: focus it if Hyprland sees it
    if command -v hyprctl >/dev/null 2>&1; then
      for _ in $(seq 1 60); do
        if hyprctl clients 2>/dev/null | grep -q "class: antigravity"; then
          hyprctl dispatch focuswindow "class:^antigravity$" >/dev/null 2>&1 || true
          break
        fi
        sleep 0.1
      done
    fi

    wait "$pid"
  '';

  # Optional: claude as your user, sandboxed to cwd (no sudo boundary).
  claudeSandbox = pkgs.writeShellScriptBin "claude-sandbox" ''
    set -euo pipefail
    WORK="''${PWD}"
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/claude-sandbox-home"
    mkdir -p "$SANDBOX_HOME"/{.config,.cache,.local/share}

    exec ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-user \
      --unshare-pid \
      --unshare-uts \
      --unshare-cgroup \
      --share-net \
      --die-with-parent \
      --new-session \
      --proc /proc \
      --dev /dev \
      --ro-bind /nix /nix \
      --ro-bind /etc /etc \
      --ro-bind /run/current-system /run/current-system \
      --bind /tmp /tmp \
      --bind "$WORK" /work \
      --chdir /work \
      --bind "$SANDBOX_HOME" "$SANDBOX_HOME" \
      --setenv HOME "$SANDBOX_HOME" \
      --setenv PATH "/run/current-system/sw/bin" \
      -- ${claudeBin} "$@"
  '';

  aido = pkgs.writeShellScriptBin "aido" ''
        set -euo pipefail

        usage() {
          cat <<'EOF'
    Usage:
      aido [--env KEY=VAL ...] [--preserve-env KEY ...] <command> [args...]

    Commands:
      claude|claude-code          runs as ai user (sudo), supports env forwarding
      claude-sandbox              runs as you in bwrap, sandboxed to cwd
      antigravity|antigravity-fhs runs as you in bwrap (Wayland-friendly)

    Examples:
      aido --env ANTHROPIC_API_KEY=... claude
      ANTHROPIC_API_KEY=... aido --preserve-env ANTHROPIC_API_KEY claude
      aido antigravity
    EOF
        }

        if [ $# -eq 0 ]; then usage; exit 1; fi

        # Collect env keys we want sudo to preserve
        preserve_keys=()

        # Parse env flags
        while [ $# -gt 0 ]; do
          case "$1" in
            --env)
              [ $# -ge 2 ] || { echo "aido: --env requires KEY=VAL" >&2; exit 2; }
              kv="$2"
              shift 2
              key="''${kv%%=*}"
              val="''${kv#*=}"
              if [ -z "$key" ] || [ "$key" = "$val" ]; then
                echo "aido: invalid --env '$kv' (expected KEY=VAL)" >&2
                exit 2
              fi
              export "$key=$val"
              preserve_keys+=("$key")
              ;;
            --preserve-env)
              [ $# -ge 2 ] || { echo "aido: --preserve-env requires KEY" >&2; exit 2; }
              key="$2"
              shift 2
              preserve_keys+=("$key")
              ;;
            --help|-h)
              usage; exit 0 ;;
            *)
              break ;;
          esac
        done

        [ $# -ge 1 ] || { usage; exit 2; }

        CMD="$1"
        shift

        if [ "$CMD" = "claude" ] || [ "$CMD" = "claude-code" ]; then
          if [ -n "''${ANTHROPIC_API_KEY:-}" ]; then
            preserve_keys+=("ANTHROPIC_API_KEY")
          fi
        fi

        # Build sudo preserve-env argument if needed
        preserve_arg=""
        if [ "''${#preserve_keys[@]}" -gt 0 ]; then
          # de-dupe
          uniq_keys="$(printf "%s\n" "''${preserve_keys[@]}" | awk '!seen[$0]++' | paste -sd, -)"
          preserve_arg="--preserve-env=$uniq_keys"
        fi

        case "$CMD" in
          claude|claude-code)
            # Run as ai, allow optional env passthrough
            exec /run/wrappers/bin/sudo $preserve_arg -u ai -g ai -- ${claudeBin} "$@"
            ;;
          claude-sandbox)
            exec ${claudeSandbox}/bin/claude-sandbox "$@"
            ;;
          antigravity|antigravity-fhs)
            exec ${antigravitySandbox}/bin/antigravity-sandbox "$@"
            ;;
          *)
            # Default: run arbitrary command as ai (no env passthrough unless you set preserve_keys)
            exec /run/wrappers/bin/sudo $preserve_arg -u ai -g ai -- "$CMD" "$@"
            ;;
        esac
  '';
in {
  options.fmf.apps.agentic-ai = {
    enable = mkBoolOpt false "Whether to enable the Agentic AI app helpers.";
    allowedUsers = mkOpt (types.listOf types.str) [ "admin" ]
      "Users allowed to use the aido command.";
  };

  config = mkIf cfg.enable {
    users.groups.ai = { };

    users.users.ai = {
      isSystemUser = true;
      group = "ai";
      shell = pkgs.bashInteractive;
      home = "/var/lib/ai";
      createHome = true;
      description = "Agentic AI System User";
      packages = aiPackages;
    };

    environment.systemPackages =
      [ aido antigravitySandbox claudeSandbox pkgs.bubblewrap ];

    # IMPORTANT: sudoers should describe the command being executed, not "sudo ..." itself.
    #
    # - Allow users to run aido without password.
    # - Allow them to run claude as user ai without password AND allow env passing (SETENV).
    security.sudo.extraRules = map (user: {
      users = [ user ];
      commands = [
        {
          command = "${aido}/bin/aido";
          options = [ "NOPASSWD" ];
        }

        # Allow running claude as ai, with arbitrary args, and allow env vars via --preserve-env / -E.
        {
          command = "${claudeBin} *";
          options = [ "NOPASSWD" "SETENV" ];
        }
      ];
      runAs = "ai";
    }) cfg.allowedUsers;

    systemd.tmpfiles.rules = [ "d /var/lib/ai 0750 ai ai -" ];
  };
}
