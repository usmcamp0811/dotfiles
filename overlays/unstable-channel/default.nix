# Packages from nixpkgs unstable channel
# These are packages we want newer versions of from unstable
# IMPORTANT: Avoid GUI-related packages here as they cause Firefox/Electron rebuilds
{channels, ...}: final: prev: {
  # Self-hosted services (server-side only, no GUI dependencies)
  inherit
    (channels.unstable)
    paperless
    n8n
    nextcloud30
    immich
    rkvm
    mealie
    # yazi
    # yaziPlugins
    ;
}
