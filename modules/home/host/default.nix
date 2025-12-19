{ lib
, host ? null
, ...
}:
let
  inherit (lib) types;
  inherit (lib.fmf) mkOpt;
in
{
  options.fmf.host = {
    name = mkOpt (types.nullOr types.str) host "The host name.";
  };
}
