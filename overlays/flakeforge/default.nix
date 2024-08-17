{ flakeforge, ... }:
final: prev: {
  streamLayeredImageConf = flakeforge.packages.x86_64-linux.flakeforgeTools.streamLayeredImageConf;
}
