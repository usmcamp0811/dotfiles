{
  pkgs,
  ...
}:
# Just use the nixpkgs version - it's kept up to date and works properly
# with pnpm v10 and pnpmWorkspaces support
pkgs.slidev-cli
