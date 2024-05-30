{ lib
, host ? null
, ...
}:
let
  inherit (lib) types;
  inherit (lib.campground) mkOpt;
in
{
  options.campground.host = {
    name = mkOpt (types.nullOr types.str) host "The host name.";
  };
}
