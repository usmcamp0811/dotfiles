{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.agentic-ai;

  aiPackages = with pkgs; [antigravity-fhs claude-code];

  # Absolute store paths (stable references) to the *real* tools.
  claudeBin = "${pkgs.claude-code}/bin/claude";
  antigravityBin = "${pkgs.antigravity-fhs}/bin/antigravity";

  # The clever sudo-like helper
  aido = pkgs.writeShellScriptBin "aido" ''
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: aido <command> [args...]"
      echo "Common commands: claude-code, antigravity-fhs"
      exit 1
    fi

    CMD="$1"
    shift

    case "$CMD" in
      claude|claude-code)
        exec /run/wrappers/bin/sudo -u ai -g ai -- ${claudeBin} "$@"
        ;;
      antigravity|antigravity-fhs)
        exec /run/wrappers/bin/sudo -u ai -g ai -- ${antigravityBin} "$@"
        ;;
      *)
        exec /run/wrappers/bin/sudo -u ai -g ai -- "$CMD" "$@"
        ;;
    esac
  '';
in {
  options.fmf.apps.agentic-ai = {
    enable = mkBoolOpt false "Whether to enable the Agentic AI service.";
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

    environment.systemPackages = [aido];

    # Only allow *aido* to be run with sudo NOPASSWD.
    security.sudo.extraRules =
      map (user: {
        users = [user];
        commands = [
          # Allow aido itself without password.
          {
            command = "${aido}/bin/aido";
            options = ["NOPASSWD"];
          }

          # HARDENING: only allow these exact sudo invocations without password.
          {
            command = "/run/wrappers/bin/sudo -u ai -g ai -- ${claudeBin}*";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/wrappers/bin/sudo -u ai -g ai -- ${antigravityBin}*";
            options = ["NOPASSWD"];
          }
        ];
      })
      cfg.allowedUsers;

    systemd.tmpfiles.rules = ["d /var/lib/ai 0750 ai ai -"];
  };
}
