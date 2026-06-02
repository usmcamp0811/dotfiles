{
  lib,
  writeText,
  writeShellApplication,
  replaceVars,
  substituteAll,
  gum,
  inputs,
  hosts ? {},
  ...
}: let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;

  substitute = args: let
    src = builtins.readFile args.src;
    argAttrs = builtins.removeAttrs args ["src"];
    keys = builtins.attrNames argAttrs;
    findPatterns = map (k: "@" + k + "@") keys;
    replaceValues = map toString (builtins.attrValues argAttrs);
  in
    lib.replaceStrings findPatterns replaceValues src;

  formatted-hosts = mapAttrsToList (name: host: "${name},${host.pkgs.stdenv.hostPlatform.system}") hosts;

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
