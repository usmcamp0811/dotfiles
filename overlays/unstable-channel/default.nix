# Packages from nixpkgs unstable channel
# These are packages we want newer versions of from unstable
# IMPORTANT: Avoid GUI-related packages here as they cause Firefox/Electron rebuilds
{ channels, ... }:
final: prev: {
  # Self-hosted services (server-side only, no GUI dependencies)
  inherit (channels.unstable)
    paperless n8n nextcloud30 immich rkvm mealie yazi yaziPlugins navidrome
    netbird netbird-signal netbird-upload netbird-dashboard netbird-management;

  # Keep unstable netbird-ui but normalize desktop Exec for NixOS wrapper compatibility
  netbird-ui = channels.unstable.netbird-ui.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      if [ -f "$out/share/applications/netbird.desktop" ]; then
        substituteInPlace "$out/share/applications/netbird.desktop" \
          --replace-fail 'Exec=netbird-ui' "Exec=$out/bin/netbird-ui"
      fi
    '';
  });
}
