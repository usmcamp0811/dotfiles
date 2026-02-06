{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.agentic-ai;

  # Tools you want available (note: antigravity GUI won't run as ai on Wayland)
  aiPackages = with pkgs; [antigravity-fhs claude-code];

  # Absolute store paths (stable references) to the *real* tools.
  claudeBin = "${pkgs.claude-code}/bin/claude";
  antigravityBin = "${pkgs.antigravity-fhs}/bin/antigravity";

  # Run antigravity as the *calling user* but sandbox it with bubblewrap.
  # This avoids Wayland permission issues while still restricting access to your real HOME.
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

    rm -f "$USER_DATA_DIR"/Singleton{Lock,Cookie,Socket} 2>/dev/null || true

    launcher="${antigravityBin}"
    launcher_real="$(readlink -f "$launcher" || echo "$launcher")"
    pkg_root="$(dirname "$(dirname "$launcher_real")")"

    # Prefer the real Electron binary if present; otherwise fall back to the launcher.
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
      --setenv ELECTRON_ENABLE_LOGGING "1" \
      --setenv ELECTRON_ENABLE_STACK_DUMPING "1" \
      -- "$real" \
        --user-data-dir="$USER_DATA_DIR" \
        --ozone-platform-hint=auto \
        --enable-features=WaylandWindowDecorations \
        --enable-wayland-ime=true \
        --wayland-text-input-version=3 \
        "$@"
  '';

  # Optional: run claude as the *calling user* but sandboxed (useful if you want repo access).
  # This is NOT the default; default still runs claude as user "ai" for a stronger boundary.
  claudeSandbox = pkgs.writeShellScriptBin "claude-sandbox" ''
    set -euo pipefail

    # Use current working dir as the only "project" surface
    WORK="''${PWD}"
    TMPHOME="$(mktemp -d -t claude-home.XXXXXX)"
    cleanup() { rm -rf "$TMPHOME"; }
    trap cleanup EXIT

    exec ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-all \
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
      --clearenv \
      --setenv HOME "$TMPHOME" \
      --setenv PATH "/run/current-system/sw/bin" \
      -- ${claudeBin} "$@"
  '';

  # aido: routes known commands to the hardened invocations
  aido = pkgs.writeShellScriptBin "aido" ''
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: aido <command> [args...]"
      echo "Common commands:"
      echo "  claude|claude-code          (runs as ai user)"
      echo "  claude-sandbox              (runs as you, sandboxed, repo-only)"
      echo "  antigravity|antigravity-fhs (runs as you, sandboxed; Wayland-compatible)"
      exit 1
    fi

    CMD="$1"
    shift

    case "$CMD" in
      claude|claude-code)
        exec /run/wrappers/bin/sudo -u ai -g ai -- ${claudeBin} "$@"
        ;;
      claude-sandbox)
        exec ${claudeSandbox}/bin/claude-sandbox "$@"
        ;;
      antigravity|antigravity-fhs)
        exec ${antigravitySandbox}/bin/antigravity-sandbox "$@"
        ;;
      *)
        # Default: run arbitrary commands as ai (still requires sudo rule permitting aido itself).
        exec /run/wrappers/bin/sudo -u ai -g ai -- "$CMD" "$@"
        ;;
    esac
  '';
in {
  options.fmf.apps.agentic-ai = {
    enable = mkBoolOpt false "Whether to enable the Agentic AI app helpers.";
    allowedUsers =
      mkOpt (types.listOf types.str) ["admin"]
      "Users allowed to use the aido command.";
  };

  config = mkIf cfg.enable {
    users.groups.ai = {};

    users.users.ai = {
      isSystemUser = true;
      group = "ai";
      shell = pkgs.bashInteractive;
      home = "/var/lib/ai";
      createHome = true;
      description = "Agentic AI System User";
      packages = aiPackages;
    };

    environment.systemPackages = [
      aido
      antigravitySandbox
      claudeSandbox
      pkgs.bubblewrap
    ];

    # Sudo policy:
    # - allowedUsers can run aido without password
    # - and can run the *exact* claude binary as ai without password (hardened)
    #
    # Note: antigravity does NOT use sudo (Wayland), so no sudo rule is needed for it.
    security.sudo.extraRules =
      map (user: {
        users = [user];
        commands = [
          {
            command = "${aido}/bin/aido";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/wrappers/bin/sudo -u ai -g ai -- ${claudeBin}*";
            options = ["NOPASSWD"];
          }
        ];
      })
      cfg.allowedUsers;

    systemd.tmpfiles.rules = [
      "d /var/lib/ai 0750 ai ai -"
    ];
  };
}
