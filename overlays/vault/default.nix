{ channels, ... }: final: prev: { inherit (channels.unstable) vault-bin vault; }
