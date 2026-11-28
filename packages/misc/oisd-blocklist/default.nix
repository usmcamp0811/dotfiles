{
  inputs,
  runCommand,
  ...
}:
# The OISD domainswild blocklist, from the `oisd-blocklist` tack pin (type = "fixed"). The pin is a
# fixed-output download fetched at build time; this wraps it as a package so downstream flakes
# (Campground) get it as pkgs.fmf.oisd-blocklist through fmf's overlays, without a pin of their own.
runCommand "oisd-domainswild" {meta.description = "OISD domainswild blocklist (big.oisd.nl mirror)";} ''
  cp ${inputs.oisd-blocklist} $out
''
