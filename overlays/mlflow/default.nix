{ channels, unstable, ... }:

final: prev:
{
  inherit (channels.unstable) python311Packages;
}
