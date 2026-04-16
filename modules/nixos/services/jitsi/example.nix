# Example Jitsi Meet Configuration for fmf-flake
# This file demonstrates how to configure Jitsi Meet in your NixOS system

{ config, ... }:

{
  # Basic Jitsi Meet setup with all defaults
  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.aicampground.com";

    # ACME/Let's Encrypt for SSL
    acme = {
      enable = true;
      email = "admin@aicampground.com";
    };

    # Vault integration (uses defaults from vault-agent)
    vault = {
      enable = true;
      vault-path = "secret/campground/jitsi";
      kvVersion = "v2"; # or "v1" depending on your Vault setup
    };

    # Coturn TURN server for WebRTC
    coturn = {
      enable = true;
      port = 3478;
      minPort = 49152;
      maxPort = 49252;
    };

    # Nginx reverse proxy
    nginx = {
      enable = true;
      port = 443;
      httpPort = 80;
    };

    # Videobridge configuration
    videobridge = {
      enable = true;
      openFirewall = true;
      port = 10000;
    };

    # Custom interface configuration
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      DEFAULT_BACKGROUND = "#1a1a1a";
      VERTICAL_FILMSTRIP = true;
      TOOLBAR_ALWAYS_VISIBLE = false;
    };

    # Custom meeting configuration
    config = {
      enableWelcomePage = true;
      prejoinPageEnabled = true;
      startAudioMuted = 10; # Mute audio for participants after 10 join
      startVideoMuted = 10; # Mute video for participants after 10 join

      # P2P configuration
      p2p = {
        enabled = true;
        stunServers = [{ urls = "stun:meet-jit-si-turnrelay.jitsi.net:443"; }];
      };

      # Disable recording features if not needed
      liveStreamingEnabled = false;
      fileRecordingsEnabled = false;
    };
  };
}

# Advanced Example: Minimal Jitsi without TURN server
# Useful for internal networks or when using external TURN servers
{
  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.internal.lan";

    # Disable TURN server
    coturn.enable = false;

    # Disable ACME for internal deployments
    acme.enable = false;

    # Use external TURN server
    config.p2p.stunServers = [
      { urls = "stun:stun.l.google.com:19302"; }
      { urls = "turn:turn.example.com:3478"; }
    ];
  };
}

# Advanced Example: With custom Vault configuration
{
  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.example.com";

    vault = {
      enable = true;
      role-id = "/custom/path/to/role-id";
      secret-id = "/custom/path/to/secret-id";
      vault-address = "https://vault.internal:8200";
      vault-path = "secret/production/jitsi";
      kvVersion = "v2";
    };
  };
}

# Advanced Example: Custom extra configuration
{
  fmf.services.jitsi = {
    enable = true;
    hostName = "meet.example.com";

    extraConfig = ''
      // Custom JavaScript configuration
      config.defaultLanguage = 'en';
      config.brandingDataUrl = 'https://example.com/branding.json';

      // Enable additional features
      config.enableNoisyMicDetection = true;
      config.enableTalkWhileMuted = true;
    '';
  };
}
