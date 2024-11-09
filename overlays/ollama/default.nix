{ channels, ... }: final: prev: { inherit (channels.unstable) ollama ollama-cuda; }
