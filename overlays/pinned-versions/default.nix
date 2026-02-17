# Packages pinned to specific versions or commits
# Use this for packages where you need a specific version
{
  channels,
  nixpkgs,
  ...
}: final: prev: {
  # Ollama from specific pinned commit
  # inherit (channels.updated-ollama) ollama ollama-cuda open-webui;

  # QEMU from main nixpkgs
  qemu = nixpkgs.legacyPackages.${prev.system}.qemu;
}
