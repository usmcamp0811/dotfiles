{
  lib,
  writeText,
  writeShellApplication,
  replaceVars,
  gum,
  inputs,
  hosts ? {},
  ...
}: let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  # replacement helper using lib.replaceVars (expects @var@ in the template)
  substitute = args: let
    src = builtins.readFile args.src;
    vars =
      builtins.mapAttrs (_: v: toString v)
      (builtins.removeAttrs args ["src"]);
  in
    replaceVars src vars;

  formatted-hosts = mapAttrsToList (name: host: "${name},${host.pkgs.system}") hosts;

  # Normal CSV with header + rows (if any)
  hosts-csv = writeText "hosts.csv" ''
    Name,System
    ${concatStringsSep "\n" formatted-hosts}
  '';

  # Always give the script a real file, even if there are no hosts
  hostsFile =
    if hosts == {}
    then
      # header-only CSV; your script can still handle “no data rows”
      writeText "hosts-empty.csv" ''
        Name,System
      ''
    else hosts-csv;

  nixos-hosts = writeShellApplication {
    name = "nixos-hosts";

    text = substitute {
      src = ./nixos-hosts.sh;

      help = ./help;
      hosts = hostsFile;
    };

    # don’t run any checks that might exec the script at build time
    checkPhase = "";

    runtimeInputs = [gum];
  };

  new-meta = with lib; {
    description = "A helper to list all of the NixOS hosts available from your flake.";
    license = licenses.asl20;
    maintainers = with maintainers; [mattcamp];
  };
in
  override-meta new-meta nixos-hosts
