{ channels, updated-ollama, ... }:
final: prev: {
  # inherit (channels.unstable) ollama ollama-cuda open-webui;
  inherit (channels.updated-ollama) ollama ollama-cuda open-webui;
}
