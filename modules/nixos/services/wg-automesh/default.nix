{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.wgautomesh;
  inherit (pkgs) wgautomesh;
in
{
  options.campground.services.wgautomesh = with types; {
    enable = mkBoolOpt false "Enable the wgautomesh service.";
    logLevel = mkOption {
      type = enum [ "trace" "debug" "info" "warn" "error" ];
      default = "info";
      description = "wgautomesh log level.";
    };
    enableGossipEncryption =
      mkBoolOpt true "Enable encryption of gossip traffic.";
    enablePersistence = mkBoolOpt true "Enable persistence of peer info.";
    interface = mkOpt str "campnet" "Wireguard interface to manage.";
    gossipPort = mkOpt int 1666 "Gossip port used for peer discovery.";
    peers = mkOption {
      type = listOf (attrsOf str);
      default = [ ];
      description = "List of peer configurations.";
    };

    vault-path = mkOpt str "secret/wgautomesh"
      "The Vault path to the KV containing gossip secrets.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "Vault KV store version.";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault.";
    };
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Path to the Vault role-id.";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Path to the Vault secret-id.";
  };

  config = mkIf cfg.enable {
    services.wgautomesh = {
      enable = true;
      logLevel = cfg.logLevel;
      enableGossipEncryption = cfg.enableGossipEncryption;
      gossipSecretFile = "/var/lib/wireguard/gossip_secret";
      enablePersistence = cfg.enablePersistence;
      openFirewall = true;
      settings = {
        interface = cfg.interface;
        gossip_port = cfg.gossipPort;
        peers = cfg.peers;
      };
    };

    systemd.tmpfiles.rules =
      [ "d /run/secrets/wgautomesh 0700 wgautomesh wgautomesh -" ];

    campground.services.vault-agent.services.wgautomesh = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = cfg.role-id;
              secret_id_file_path = cfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets.environment.templates = {
        wgautomesh = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            GOSSIP_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.GOSSIP_SECRET }}{{ else }}{{ .Data.data.GOSSIP_SECRET }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
