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

  # substituteAll -> replaceVars
  substitute = args: let
    # Read the template file
    src = builtins.readFile args.src;

    # Everything except src becomes a variable
    vars =
      builtins.mapAttrs (_: v: toString v)
      (builtins.removeAttrs args ["src"]);
  in
    replaceVars src vars;

  formatted-hosts = mapAttrsToList (name: host: "${name},${host.pkgs.system}") hosts;

  hosts-csv = writeText "hosts.csv" ''
    Name,System
    ${concatStringsSep "\n" formatted-hosts}
  '';

  nixos-hosts = writeShellApplication {
    name = "nixos-hosts";

    text = substitute {
      src = ./nixos-hosts.sh;

      help = ./help;
      hosts =
        if hosts == {}
        then ""
        else hosts-csv;
    };

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
