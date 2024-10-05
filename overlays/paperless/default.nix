{ channels, ... }:
final: prev: {
  inherit (channels.unstable) immich paperless;
}
