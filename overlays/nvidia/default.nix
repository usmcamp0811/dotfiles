{ unstable, channels, ... }:

self: super: {
  nvidia_x11 = super.nvidia_x11.overrideAttrs (oldAttrs: {
    src = self.unstable.nvidia_x11.src;
  });
}
