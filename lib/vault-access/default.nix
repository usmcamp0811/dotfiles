# Derive least-privilege Vault policies from what vault-agent templates read.
#
#   lib.fmf.vaultAccess.extractHost config          # one evaluated host -> { enabled, services }
#   lib.fmf.vaultAccess.render { mount; hosts; }    # { <host> = extractHost ...; } -> files
#
# render returns
#   policies = { "svc-<service>" = "<hcl>"; ... }   one per vault-agent service (and distinct secret set)
#   hosts    = { "<host>" = [ "svc-..." ]; ... }     which policies each host's role should carry
#   mapping  = "<nix text>"                         `hosts`, as the committed service-policies.nix
#
# Self-contained on purpose (only needs nixpkgs lib): the `vault-access` package and downstream checks
# import this file directly. See docs/VAULT-APPROLES.md.
{lib, ...}: let
  inherit
    (lib)
    attrNames
    attrValues
    concatMap
    concatLists
    concatStringsSep
    filter
    groupBy
    hasInfix
    hasPrefix
    head
    last
    length
    listToAttrs
    mapAttrs
    mapAttrsToList
    nameValuePair
    removePrefix
    sort
    splitString
    toLower
    unique
    ;

  # ---- extraction: one evaluated host ----------------------------------------------------------

  # A template is inline `text` or a `source` file; a source is read so its calls are visible.
  asText = v:
    if v == null
    then null
    else if builtins.isPath v || (builtins.isString v && hasPrefix "/nix/store/" v)
    then builtins.readFile v
    else v;
  pick = t:
    if t.text != null
    then t.text
    else t.source;

  templatesOf = svc:
    (mapAttrsToList (_: t: asText (pick t)) svc.secrets.file.files)
    ++ (mapAttrsToList (_: t: asText (pick t)) svc.secrets.environment.templates)
    ++ (lib.optional (svc.secrets.environment.template != null) (asText svc.secrets.environment.template));

  # {{ with secret "x" ... }}  /  {{- secret "x" }}  /  {{ with pkiCert "x" ... }}
  # (the matches are plain Vault paths; drop string context so a template that interpolates store
  # paths cannot make a policy file depend on building them)
  callsIn = text:
    map (m: {
      fn = builtins.unsafeDiscardStringContext (builtins.elemAt m 1);
      path = builtins.unsafeDiscardStringContext (builtins.elemAt m 2);
    }) (filter builtins.isList
      (builtins.split ''\{\{-?[[:space:]]*(with[[:space:]]+)?(secret|pkiCert)[[:space:]]+"([^"]+)"'' text));

  extractHost = config: let
    cfg = lib.attrByPath ["fmf" "services" "vault-agent"] {enable = false;} config;
  in
    if !(cfg.enable or false)
    then {
      enabled = false;
      services = {};
    }
    else {
      enabled = true;
      services =
        mapAttrs
        (_: svc: unique (concatMap (t:
          if t == null
          then []
          else callsIn t) (templatesOf svc)))
        cfg.services;
    };

  # ---- policy rules -----------------------------------------------------------------------------

  # KV v2 template paths resolve under `mount`: secret/campground/x -> secret/campground/data/x.
  # A template that already spells .../data/x is kept as is (never data/data).
  ruleOf = mount: call: let
    p = call.path;
  in
    if hasInfix "-pki/" p || hasInfix "/pki/" p
    then {
      path = p;
      caps =
        if hasInfix "/issue/" p
        then ["update"]
        else ["read"];
      kind = "pki";
      logical = null;
    }
    else if hasPrefix "${mount}/data/" p
    then {
      path = p;
      caps = ["read"];
      kind = "kv";
      logical = "${mount}/${removePrefix "${mount}/data/" p}";
    }
    else if hasPrefix "${mount}/" p
    then {
      path = "${mount}/data/${removePrefix "${mount}/" p}";
      caps = ["read"];
      kind = "kv";
      logical = p;
    }
    else {
      path = p;
      caps = [];
      kind = "unresolved";
      logical = null;
    };

  # unique by resulting path, sorted by it
  rulesOf = mount: calls:
    attrValues (listToAttrs (map (c: let
      r = ruleOf mount c;
    in
      nameValuePair r.path r)
    calls));

  stanza = mount: r:
    if r.kind == "unresolved"
    then "# UNRESOLVED (not under ${mount} and not a PKI path), no access granted: ${r.path}\n"
    else
      ''
        path "${r.path}" {
          capabilities = [${concatStringsSep ", " (map (c: ''"${c}"'') r.caps)}]
        }
      ''
      + lib.optionalString (r.kind == "kv") ''
        # KV v2 mount discovery for the agent, no secret data
        path "sys/internal/ui/mounts/${r.logical}" {
          capabilities = ["read"]
        }
      '';

  # ---- units: one policy per (service name, distinct set of secrets) -----------------------------

  unitsOf = mount: hosts: let
    rows = concatLists (mapAttrsToList (host: d:
      if !d.enabled
      then []
      else
        filter (r: r.rules != []) (mapAttrsToList (svc: calls: {
            inherit host svc;
            rules = rulesOf mount calls;
          })
          d.services))
    hosts);

    perService = svc: srows: let
      variants = groupBy (r: builtins.toJSON (map (x: x.path) r.rules)) srows;
      multi = length (attrNames variants) > 1;
    in
      mapAttrsToList (_: vrows: let
        rules = (head vrows).rules;
        leaf = r: last (splitString "/" r.path);
      in {
        inherit svc rules;
        hosts = unique (map (r: r.host) vrows);
        # Vault lowercases policy names and the vault module compares names literally, so we do too.
        # Several secret sets under one service name => the name carries the secrets.
        name = "svc-${toLower svc}" + lib.optionalString multi "--${toLower (concatStringsSep "-" (map leaf rules))}";
      })
      variants;

    units = concatLists (mapAttrsToList perService (groupBy (r: r.svc) rows));
    collisions = filter (g: length g > 1) (attrValues (groupBy (u: u.name) units));
  in
    if collisions != []
    then throw "vault-access: policy name collision (Vault policy names are case-insensitive): ${concatStringsSep ", " (map (g: (head g).name) collisions)}"
    else units;

  render = {
    mount ? "secret/campground",
    hosts,
  }: let
    units = unitsOf mount hosts;
    sorted = sort builtins.lessThan;

    policyText = u:
      ''
        # GENERATED by `vault-access` from the vault-agent templates of service "${u.svc}".
        # Do not edit: change the module/host config and regenerate with `vault-access` (fmf package; see docs/VAULT-APPROLES.md).
        # Grants exactly the secrets that service reads. KV mount: ${mount} (v2).

      ''
      + concatStringsSep "\n" (map (stanza mount) u.rules)
      + "\n";

    hostPolicies =
      mapAttrs (_: ps: sorted (unique (map (p: p.n) ps)))
      (groupBy (p: p.h) (concatMap (u: map (h: {
          inherit h;
          n = u.name;
        })
        u.hosts)
      units));
  in {
    policies = listToAttrs (map (u: nameValuePair u.name (policyText u)) units);
    hosts = hostPolicies;
    mapping =
      ''
        # GENERATED by `vault-access`; do not edit; regenerate with `vault-access` (fmf package).
        # host -> generated per-service policies its vault-agent services need.
        {
      ''
      + concatStringsSep "\n" (mapAttrsToList (h: ps: "  \"${h}\" = [${concatStringsSep " " (map (p: "\"${p}\"") ps)}];") hostPolicies)
      + "\n}\n";
  };
in {
  vaultAccess = {inherit extractHost render;};
}
