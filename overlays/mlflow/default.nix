{ channels, unstable, ... }:

final: prev:
{
  inherit (channels.unstable) python311Packages python3 poetry;
}
