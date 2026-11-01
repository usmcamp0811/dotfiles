# Small, pure IPv4/IPv6 helpers used by the Circuit Breaker inventory exporter.
#
# Nix has no network-address library, and the exporter needs exactly two
# things: "which declared network contains this address?" and "what is the
# canonical network address of this interface address?". IPv4 is handled with
# integer arithmetic; IPv6 is carried through verbatim (family detection and
# CIDR splitting only) because the exporter never needs IPv6 containment.
{lib}: let
  inherit (builtins) match elemAt length;

  pow2 = n: builtins.foldl' (acc: _: acc * 2) 1 (lib.range 1 n);

  isV4 = s: builtins.isString s && match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" s != null;
  isV6 = s: builtins.isString s && lib.hasInfix ":" s;

  # "10.8.0.20" -> 168165396, or null when not a valid dotted quad.
  v4ToInt = s: let
    m = match "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)" s;
    octets = map lib.toInt m;
  in
    if m == null || builtins.any (o: o > 255) octets
    then null
    else builtins.foldl' (acc: o: acc * 256 + o) 0 octets;

  intToV4 = n:
    lib.concatStringsSep "." (map
      (shift: toString (lib.mod (builtins.div n shift) 256))
      [16777216 65536 256 1]);

  v4Mask = prefix: 4294967296 - pow2 (32 - prefix);

  # "10.8.0.20/24" or "10.8.0.0/24" -> { family, address, prefixLength, cidr, network }
  # cidr is the *canonical network* ("10.8.0.0/24"); address is the host part as written.
  parseCidr = s: let
    m = match "([^/]+)/([0-9]+)" s;
    addr =
      if m == null
      then s
      else elemAt m 0;
    prefix =
      if m == null
      then null
      else lib.toInt (elemAt m 1);
  in
    if isV4 addr
    then let
      p =
        if prefix == null
        then 32
        else prefix;
      n = v4ToInt addr;
    in
      if n == null || p > 32
      then null
      else {
        family = "ipv4";
        address = addr;
        prefixLength = p;
        network = intToV4 (builtins.bitAnd n (v4Mask p));
        cidr = "${intToV4 (builtins.bitAnd n (v4Mask p))}/${toString p}";
      }
    else if isV6 addr
    then let
      p =
        if prefix == null
        then 128
        else prefix;
    in
      if p > 128
      then null
      else {
        family = "ipv6";
        address = addr;
        prefixLength = p;
        network = addr;
        cidr = "${addr}/${toString p}";
      }
    else null;

  # Is the address (plain, no prefix) inside the CIDR? IPv4 only; IPv6 is
  # never reported as contained because the exporter cannot prove it.
  inCidr = cidr: address: let
    c = parseCidr cidr;
    n =
      if isV4 address
      then v4ToInt address
      else null;
  in
    c
    != null
    && c.family == "ipv4"
    && n != null
    && builtins.bitAnd n (v4Mask c.prefixLength) == v4ToInt c.network;

  isLoopback = a: lib.hasPrefix "127." a || a == "::1";
  isLinkLocal = a: lib.hasPrefix "169.254." a || lib.hasPrefix "fe80:" a;
in {
  inherit isV4 isV6 v4ToInt intToV4 parseCidr inCidr isLoopback isLinkLocal;
}
