# Which Vault paths does one host's vault-agent actually read?
#
#   nix eval --impure --json --expr \
#     '(import ./extract.nix) { flake = "git+file:///path/to/downstream-flake"; host = "vm-media"; }'
#
# Reads the *evaluated* config.fmf.services.vault-agent, takes every template (inline `text` or
# `source` file, file and environment kinds) and pulls out each `secret "<path>"` /
# `pkiCert "<path>"` call. Result:
#   { enabled = true; services = { <service> = [ { fn = "secret"; path = "..."; } ... ]; }; }
# Templates are the only place a vault-agent can read from, so this is exact for them. It does
# NOT see Vault access that happens outside a template (CLI use, the policy agent); those need
# hand-written policies.
{
  flake,
  host,
}: let
  f = builtins.getFlake flake;
  # the host's own nixpkgs lib, so the downstream flake needs no particular input name
  lib = f.nixosConfigurations.${host}.pkgs.lib;
  cfg = f.nixosConfigurations.${host}.config.fmf.services.vault-agent;

  asText = v:
    if v == null
    then null
    else if builtins.isPath v || (builtins.isString v && lib.hasPrefix "/nix/store/" v)
    then builtins.readFile v
    else v;
  pick = t:
    if t.text != null
    then t.text
    else t.source;

  templatesOf = svc:
    (lib.mapAttrsToList (_: t: asText (pick t)) svc.secrets.file.files)
    ++ (lib.mapAttrsToList (_: t: asText (pick t)) svc.secrets.environment.templates)
    ++ (lib.optional (svc.secrets.environment.template != null) (asText svc.secrets.environment.template));

  # {{ with secret "x" ... }}  /  {{- secret "x" }}  /  {{ with pkiCert "x" ... }}
  calls = text:
    map (m: {
      fn = builtins.elemAt m 1;
      path = builtins.elemAt m 2;
    }) (builtins.filter builtins.isList
      (builtins.split ''\{\{-?[[:space:]]*(with[[:space:]]+)?(secret|pkiCert)[[:space:]]+"([^"]+)"'' text));
in
  if !(cfg.enable or false)
  then {enabled = false;}
  else {
    enabled = true;
    services =
      lib.mapAttrs
      (_: svc: lib.unique (lib.concatMap (t:
        if t == null
        then []
        else calls t) (templatesOf svc)))
      cfg.services;
  }
