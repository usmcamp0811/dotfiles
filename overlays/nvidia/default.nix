{ channels, ... }:

final: prev:

{
  nvidia_x11 = prev.nvidia_x11 // {
    inherit (channels.unstable.nvidia_x11);
  };
}
