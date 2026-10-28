{pkgs, lib, ...}: let
  mock = pkgs.writeShellScript "mock-skills" ''
    printf '%s\n' "$*" >> "$CALLS"
    if [ "''${FAIL_ALL:-0}" = 1 ]; then exit 1; fi
    case " $* " in *" --skill missing "*) exit 1;; esac
  '';
  script = strict: sources: pkgs.writeShellScript "test-install-skills" ''
    set -euo pipefail
    run() {
      if [ "''${DRY_RUN:-0}" = 1 ]; then return 0; fi
      "$@"
    }
    ${import ../../modules/home/tools/agentic-ai/install-skills.nix {
      inherit lib sources strict;
      command = toString mock;
    }}
    touch "$MARKER"
  '';
  sources = ["@owner/repo/missing" "@owner/repo/available"];
  aliases = (import ../../lib/module {inherit lib;}).convertAlias {
    dkill = ''printf '%s\n' "$1"'';
    with-hyphen = ''printf '%s\n' "$1"'';
    simple = "printf '%s' 'an apostrophe'";
  };
  aliasFile = pkgs.writeText "aliases.shrc" aliases;
  invalid = builtins.tryEval (builtins.deepSeq
    ((import ../../lib/module {inherit lib;}).convertAlias {"bad;name" = "$1";}) true);
in assert !invalid.success;
pkgs.runCommand "agentic-ai-activation-regression" {nativeBuildInputs = [pkgs.bash pkgs.zsh pkgs.gnugrep];} ''
  export CALLS="$TMPDIR/calls" MARKER="$TMPDIR/continued"
  ${script false sources} 2> warnings
  test -f "$MARKER"
  test "$(wc -l < "$CALLS")" -eq 2
  grep -q 'Warning: OpenCode skill installation failed' warnings
  grep -q 'add owner/repo --skill available --global --agent opencode --yes' "$CALLS"

  rm "$CALLS" "$MARKER"
  export FAIL_ALL=1
  ${script false sources} 2> warnings
  test -f "$MARKER"
  test "$(wc -l < "$CALLS")" -eq 2

  rm "$CALLS" "$MARKER"
  if ${script true sources} 2> warnings; then exit 1; fi
  test ! -e "$MARKER"
  test "$(wc -l < "$CALLS")" -eq 1

  rm "$CALLS"
  export DRY_RUN=1
  ${script false sources}
  test ! -e "$CALLS"
  unset DRY_RUN FAIL_ALL
  ${script false []}
  test ! -e "$CALLS"

  bash -n ${aliasFile}
  zsh -n ${aliasFile}
  test "$(bash -c 'source ${aliasFile}; dkill first; with-hyphen second')" = "$(printf 'first\nsecond')"
  test "$(zsh -c 'source ${aliasFile}; dkill first; with-hyphen second')" = "$(printf 'first\nsecond')"
  touch "$out"
''
