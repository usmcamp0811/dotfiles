# Packages pinned to specific versions or commits
# Use this for packages where you need a specific version
{
  channels,
  nixpkgs,
  ...
}: final: prev: let
  system = prev.stdenv.hostPlatform.system;
in {
  # Ollama from specific pinned commit
  # inherit (channels.updated-ollama) ollama ollama-cuda open-webui;

  # QEMU from main nixpkgs
  qemu = nixpkgs.legacyPackages.${system}.qemu;

  # Pin opencode to v1.3.13 inside llm-agents
  # llm-agents = prev.llm-agents // {
  #   opencode = prev.llm-agents.opencode.overrideAttrs (_old:
  #     let
  #       version = "1.3.13";
  #       assets = {
  #         x86_64-linux = "opencode-linux-x64.tar.gz";
  #         aarch64-linux = "opencode-linux-arm64.tar.gz";
  #         x86_64-darwin = "opencode-darwin-x64.zip";
  #         aarch64-darwin = "opencode-darwin-arm64.zip";
  #       };
  #       hashes = {
  #         x86_64-linux = "sha256-CKwqkdjwcbDlu37AhmXH+US8ugCm/gK7ZjONdK0GesU=";
  #         aarch64-linux = "sha256-r5EzzrXZlXJl1zBFZVSqfDiqvI/zgnOUoj0/6sj+fvI=";
  #         x86_64-darwin = "sha256-j9hKu2gqwOznJuZaPba917qgFDyWhCUpQoO+4fBYuzc=";
  #         aarch64-darwin =
  #           "sha256-y72/oZ0Z+VU4kJsK8qSfi65wuk9bb0DRfG67nRnyPzM=";
  #       };
  #       platform = prev.stdenv.hostPlatform.system;
  #       asset = assets.${platform} or (throw
  #         "Unsupported system for opencode: ${platform}");
  #     in {
  #       inherit version;
  #       src = prev.fetchurl {
  #         url =
  #           "https://github.com/anomalyco/opencode/releases/download/v${version}/${asset}";
  #         hash = hashes.${platform};
  #       };
  #     });
  # };
}
