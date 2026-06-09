{ channels, unstable, nixpkgs, ... }:
final: prev:
{
  nix-unstable = unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
} // {
  inherit (channels.unstable) deploy-rs;
}
