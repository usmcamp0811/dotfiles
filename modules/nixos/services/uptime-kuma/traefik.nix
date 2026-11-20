# Uptime Kuma monitors derived from Traefik routers.
#
# Pure Nix. Reads `services.traefik.dynamicConfigOptions.http` from the named hosts in
# `nixosConfigurations` and returns one HTTP monitor per router that:
#   * has a rule made only of `Host(`name`)` terms joined by `||` (the first name is checked),
#     so sub-routes such as `Host(...) && PathPrefix(...)`, `HostRegexp(...)` and TCP routers
#     are skipped: the plain host route already covers that hostname;
#   * points at a service that is "enabled": an internal service (`api@internal`), a
#     non-loadBalancer service (weighted, mirroring, failover), or a loadBalancer with at least
#     one server. A loadBalancer with no servers is what `lookupServiceEndpoint` produces when
#     no host enables the service, so that router is skipped.
# Monitors are keyed `<label>/<router>`; that key is the identity the provisioner tags them with.
{lib}: {
  nixosConfigurations,
  # label -> host name in nixosConfigurations, e.g. { lan = "proxy-a"; }
  hosts,
  httpsEntryPoints ? ["websecure"],
}: let
  inherit (lib) any attrNames concatLists filter hasInfix mapAttrsToList listToAttrs nameValuePair;

  trim = s: let m = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" s; in if m == null then "" else builtins.head m;

  # `Host(`a`) || Host(`b`)` -> ["a" "b"]; anything else -> null.
  hostsOfRule = rule: let
    terms = map trim (filter builtins.isString (builtins.split "\\|\\|" rule));
    names = map (t: builtins.match "Host\\(`([^`]+)`\\)" t) terms;
  in
    if names != [] && all' (n: n != null) names
    then map builtins.head names
    else null;
  all' = pred: l: builtins.all pred l;

  monitorsOf = label: host: let
    sys =
      nixosConfigurations.${host}
      or (throw "fmf.services.uptime-kuma.traefik.hosts.${label}: no nixosConfiguration named '${host}'");
    http = (sys.config.services.traefik.dynamicConfigOptions or {}).http or {};
    routers = http.routers or {};
    services = http.services or {};

    serviceEnabled = name:
      hasInfix "@" name
      || (services ? ${name}
        && (
          let s = services.${name}; in
            if s ? loadBalancer
            then (s.loadBalancer.servers or []) != []
            else true
        ));

    one = router: let
      r = routers.${router};
      names = hostsOfRule (r.rule or "");
      eps = r.entryPoints or null;
      https = eps == null || any (e: builtins.elem e httpsEntryPoints) eps;
    in
      if names == null || !(serviceEnabled (r.service or ""))
      then []
      else [
        (nameValuePair "${label}/${router}" {
          type = "http";
          url = "${if https then "https" else "http"}://${builtins.head names}";
          description = "Traefik router '${router}' on ${host}: ${r.rule}";
        })
      ];
  in
    concatLists (map one (attrNames routers));
in
  listToAttrs (concatLists (mapAttrsToList monitorsOf hosts))
