# Packages from nixpkgs unstable channel
# These are packages we want newer versions of from unstable
# IMPORTANT: Avoid GUI-related packages here as they cause Firefox/Electron rebuilds
{ channels, ... }:
final: prev: {
  # Self-hosted services (server-side only, no GUI dependencies)
  #
  # NOTE: netbird-ui's desktop file must keep the literal `Exec=netbird-ui`
  # produced upstream. The `services.netbird` NixOS module (nixos/modules/
  # services/networking/netbird.nix) builds a per-client wrapper package and
  # does its own `--replace-fail 'Exec=netbird-ui' ...` substitution against
  # that file when assembling the wrapped netbird-ui binary. If we rewrite
  # Exec to an absolute store path here first, that substitution no longer
  # matches and the wrapper-netbird derivation fails to build. Do not
  # override netbird-ui's postInstall to point Exec at an absolute path.
  inherit (channels.unstable)
    paperless n8n nextcloud30 immich rkvm mealie yazi yaziPlugins navidrome
    netbird netbird-ui netbird-signal netbird-upload netbird-dashboard
    netbird-management;
}
