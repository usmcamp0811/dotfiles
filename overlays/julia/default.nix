{channels, ...}: final: prev: {
  inherit (channels.nixpkgs-julia) julia;
}
