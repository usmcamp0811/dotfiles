{ unstable, channels, ... }:
final: prev: {
  inherit (channels.unstable) flink;
}
