{ channels, ... }: final: prev: {
  # inherit (channels.prev-nixpkgs) ollama ollama-cuda open-webui;
  inherit (channels.updated-ollama) ollama ollama-cuda open-webui;
}
