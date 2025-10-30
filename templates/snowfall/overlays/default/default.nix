{ channels, unstable, nixpkgs, ... }:
final: prev:
{
  nix-unstable = unstable.legacyPackages.${prev.system};
} // {
  inherit (channels.unstable) deploy-rs;
}
