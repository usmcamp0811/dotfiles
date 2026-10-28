{lib, sources, command, strict ? false}: let
  args = source: let
    legacy = builtins.match "@([^/]+)/([^/]+)/([^/]+)" source;
  in if legacy == null then [source] else [
    "${builtins.elemAt legacy 0}/${builtins.elemAt legacy 1}"
    "--skill"
    (builtins.elemAt legacy 2)
  ];
in lib.concatMapStringsSep "\n" (source: ''
  if ! run ${lib.escapeShellArg command} add ${lib.escapeShellArgs (args source)} --global --agent opencode --yes; then
    echo ${lib.escapeShellArg "Warning: OpenCode skill installation failed: ${source}"} >&2
    ${lib.optionalString strict "exit 1"}
  fi
'') sources
