{ channels, ... }:
final: prev: {
  inherit (channels.unstable) nvidia_x11 nvidia_prime;
}
