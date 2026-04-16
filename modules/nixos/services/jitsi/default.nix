{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.jitsi;
in {
  options.fmf.services.jitsi = with types; {
    enable = mkBoolOpt false "Enable Jitsi Meet video conferencing";

    hostName = mkOpt str "meet.aicampground.com" "Hostname for Jitsi Meet";

    # Nginx configuration
    nginx = {
      enable = mkBoolOpt true "Enable nginx for Jitsi Meet";
      port = mkOpt int 443 "Port to listen on for HTTPS";
      httpPort = mkOpt int 80 "Port to listen on for HTTP (redirects to HTTPS)";
    };

    # TURN server configuration
    coturn = {
      enable = mkBoolOpt true "Enable integrated TURN server for WebRTC";
      port = mkOpt int 3478 "TURN server port";
      minPort = mkOpt int 49152 "Minimum port for TURN server relay";
      maxPort = mkOpt int 49252 "Maximum port for TURN server relay";
    };

    # Jitsi components configuration
    videobridge = {
      enable = mkBoolOpt true "Enable Jitsi Videobridge";
      openFirewall = mkBoolOpt true "Open firewall ports for Jitsi Videobridge";
      port = mkOpt int 10000 "Port for Jitsi Videobridge";
      xmppHost = mkOpt str "localhost" "XMPP host for Jitsi Videobridge";
    };

    jicofo = {
      enable = mkBoolOpt true "Enable Jicofo (Jitsi Conference Focus)";
      xmppHost = mkOpt str "localhost" "XMPP host for Jicofo";
    };

    prosody = {
      enable = mkBoolOpt true "Enable Prosody XMPP server";
      virtualHosts =
        mkOpt (listOf str) [ ] "Additional virtual hosts for Prosody";
    };

    # Interface configuration
    interfaceConfig = mkOpt attrs {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
      DEFAULT_BACKGROUND = "#474747";
      DISABLE_VIDEO_BACKGROUND = false;
      INITIAL_TOOLBAR_TIMEOUT = 20000;
      TOOLBAR_TIMEOUT = 4000;
      TOOLBAR_ALWAYS_VISIBLE = false;
      DEFAULT_REMOTE_DISPLAY_NAME = "Fellow Jitster";
      DEFAULT_LOCAL_DISPLAY_NAME = "me";
      SHOW_CHROME_EXTENSION_BANNER = false;
      RECENT_LIST_ENABLED = false;
      ENABLE_FEEDBACK_ANIMATION = true;
      DISABLE_FOCUS_INDICATOR = false;
      DISABLE_DOMINANT_SPEAKER_INDICATOR = false;
      VERTICAL_FILMSTRIP = true;
      CLOSE_PAGE_GUEST_HINT = false;
      SHOW_PROMOTIONAL_CLOSE_PAGE = false;
    } "Interface configuration for Jitsi Meet";

    # Main Jitsi Meet configuration
    config = mkOpt attrs {
      enableWelcomePage = true;
      enableClosePage = false;
      defaultLang = "en";
      prejoinPageEnabled = true;
      requireDisplayName = false;
      disableDeepLinking = false;
      enableNoisyMicDetection = true;
      startAudioMuted = 10;
      startVideoMuted = 10;
      channelLastN = -1;
      startWithAudioMuted = false;
      startWithVideoMuted = false;
      enableLayerSuspension = true;
      liveStreamingEnabled = false;
      fileRecordingsEnabled = false;
      recordingService = {
        enabled = false;
        sharingEnabled = false;
      };
      enableUserRolesBasedOnToken = false;
      enableInsecureRoomNameWarning = false;
      p2p = {
        enabled = true;
        stunServers = [{ urls = "stun:meet-jit-si-turnrelay.jitsi.net:443"; }];
      };
    } "Main configuration for Jitsi Meet";

    # Vault integration
    vault = {
      enable = mkBoolOpt true "Enable Vault integration for secrets";
      role-id = mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
      secret-id =
        mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
      vault-path = mkOpt str "secret/campground/jitsi"
        "The Vault path to the KV containing Jitsi secrets";
      kvVersion = mkOption {
        type = enum [ "v1" "v2" ];
        default = "v2";
        description = "KV store version";
      };
      vault-address = mkOption {
        type = str;
        default = config.fmf.services.vault-agent.settings.vault.address;
        description = "The address of your Vault";
      };
    };

    # ACME/SSL configuration
    acme = {
      enable = mkBoolOpt true "Enable ACME for SSL certificates";
      email = mkOpt str "" "Email for ACME registration";
    };

    # Extra configuration
    extraConfig = mkOpt lines "" "Extra configuration to append to config.js";
  };

  config = mkIf cfg.enable {
    # Enable Jitsi Meet service
    services.jitsi-meet = {
      enable = true;
      hostName = cfg.hostName;

      nginx.enable = cfg.nginx.enable;

      # Jitsi Videobridge
      videobridge = {
        enable = cfg.videobridge.enable;
        passwordFile =
          mkIf cfg.vault.enable "/tmp/detsys-vault/videobridge-secret";
      };

      # Jicofo (Conference Focus)
      jicofo.enable = cfg.jicofo.enable;

      # Prosody XMPP server
      prosody.enable = cfg.prosody.enable;

      # Interface configuration
      interfaceConfig = cfg.interfaceConfig;

      # Main configuration
      config = cfg.config;

      # TURN server configuration if enabled
      extraConfig = cfg.extraConfig + optionalString cfg.coturn.enable ''
        config.p2p.stunServers = [
          { urls: 'stun:${cfg.hostName}:${toString cfg.coturn.port}' }
        ];
      '';
    };

    # Additional Jitsi Videobridge configuration
    services.jitsi-videobridge = mkIf cfg.videobridge.enable {
      openFirewall = cfg.videobridge.openFirewall;
      # Note: The NixOS module automatically configures XMPP connection to localhost
    };

    # Coturn TURN server configuration
    services.coturn = mkIf cfg.coturn.enable {
      enable = true;
      use-auth-secret = true;
      static-auth-secret-file = "/tmp/detsys-vault/jitsi-turn-secret";
      realm = cfg.hostName;
      min-port = cfg.coturn.minPort;
      max-port = cfg.coturn.maxPort;
      no-cli = true;
      no-tcp-relay = true;
      cert = mkIf cfg.acme.enable ''
        ${config.security.acme.certs.${cfg.hostName}.directory}/fullchain.pem
      '';
      pkey = mkIf cfg.acme.enable ''
        ${config.security.acme.certs.${cfg.hostName}.directory}/key.pem
      '';
      extraConfig = ''
        listening-ip=0.0.0.0
        external-ip=${cfg.hostName}
        fingerprint
        no-tlsv1
        no-tlsv1_1
        no-multicast-peers
      '';
    };

    # Prosody XMPP configuration
    services.prosody = mkIf cfg.prosody.enable {
      extraConfig = ''
        Component "conference.${cfg.hostName}" "muc"
          storage = "memory"
          modules_enabled = {
            "muc_meeting_id";
            "muc_domain_mapper";
          }
          admins = { "focus@auth.${cfg.hostName}" }
          muc_room_locking = false
          muc_room_default_public_jids = true

        VirtualHost "auth.${cfg.hostName}"
          ssl = {
            key = "/var/lib/jitsi-meet/auth.${cfg.hostName}.key";
            certificate = "/var/lib/jitsi-meet/auth.${cfg.hostName}.crt";
          }
          authentication = "internal_hashed"

        Component "internal.auth.${cfg.hostName}" "muc"
          storage = "memory"
          modules_enabled = {
            "ping";
          }
          admins = { "focus@auth.${cfg.hostName}", "jvb@auth.${cfg.hostName}" }
          muc_room_locking = false
          muc_room_default_public_jids = true
      '';
    };

    # ACME certificates
    security.acme = mkIf cfg.acme.enable {
      acceptTerms = true;
      defaults.email = mkIf (cfg.acme.email != "") cfg.acme.email;
      certs.${cfg.hostName} = { group = mkIf cfg.coturn.enable "turnserver"; };
    };

    # Nginx configuration
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.${cfg.hostName} = {
        enableACME = cfg.acme.enable;
        forceSSL = cfg.acme.enable;
        listen = [{
          addr = "0.0.0.0";
          port = cfg.nginx.port;
          ssl = cfg.acme.enable;
        }] ++ optional (!cfg.acme.enable) {
          addr = "0.0.0.0";
          port = cfg.nginx.httpPort;
        };
      };
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [ ] ++ optional cfg.nginx.enable cfg.nginx.port
        ++ optional (cfg.nginx.enable && !cfg.acme.enable) cfg.nginx.httpPort
        ++ optional cfg.coturn.enable cfg.coturn.port;

      allowedUDPPorts = [ ]
        ++ optional cfg.videobridge.enable cfg.videobridge.port
        ++ optional cfg.coturn.enable cfg.coturn.port;

      allowedUDPPortRanges = mkIf cfg.coturn.enable [{
        from = cfg.coturn.minPort;
        to = cfg.coturn.maxPort;
      }];

      allowedTCPPortRanges = mkIf cfg.coturn.enable [{
        from = cfg.coturn.minPort;
        to = cfg.coturn.maxPort;
      }];
    };

    # Systemd services configuration
    systemd.services = {
      # TURN server permissions
      coturn =
        mkIf cfg.coturn.enable { serviceConfig.Group = mkForce "turnserver"; };

      # Ensure videobridge secret has correct ownership for jitsi-meet group
      jitsi-videobridge2 = mkIf (cfg.vault.enable && cfg.videobridge.enable) {
        serviceConfig.SupplementaryGroups = [ "jitsi-meet" ];
      };
    };

    # Vault Agent integration for secrets
    fmf.services.vault-agent = mkIf cfg.vault.enable {
      enable = true;
      services.jitsi-secrets = {
        settings = {
          vault.address = cfg.vault.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = cfg.vault.role-id;
                secret_id_file_path = cfg.vault.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets = {
          file = {
            files = {
              "jitsi-turn-secret" = mkIf cfg.coturn.enable {
                text = ''
                  {{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.TURN_SECRET }}{{ else }}{{ .Data.data.TURN_SECRET }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "videobridge-secret" = {
                text = ''
                  {{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.VIDEOBRIDGE_SECRET }}{{ else }}{{ .Data.data.VIDEOBRIDGE_SECRET }}{{ end }}{{ end }}
                '';
                permissions = "0640";
                change-action = "restart";
              };
            };
          };
        };
      };
    };

    # Create necessary directories and set permissions
    systemd.tmpfiles.rules =
      [ "d /var/lib/jitsi-meet 755 jitsi-meet jitsi-meet -" ];

    # Ensure coturn group exists if enabled
    users.groups = mkIf cfg.coturn.enable { turnserver = { }; };
  };
}
