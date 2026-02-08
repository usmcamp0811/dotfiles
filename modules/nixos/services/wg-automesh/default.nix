{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.wgautomesh;
  inherit (pkgs) wgautomesh;
in
{
  options.fmf.services.wgautomesh = with types; {
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
    gossipSecretFile = mkOpt str "/var/lib/wireguard/gossip-secret"
      "Location of the Gossip Secret";
    fetchGossipSecret =
      mkBoolOpt true "Should you get the gossip secret file from Vault?";
    peers = mkOption {
      type = listOf (attrsOf str);
      default = config.fmf.services.wireguard.peers;
      description = "List of peer configurations.";
    };
  };

  config = mkIf cfg.enable {
    services.wgautomesh = {
      enable = true;
      logLevel = cfg.logLevel;
      enableGossipEncryption = cfg.enableGossipEncryption;
      gossipSecretFile = cfg.gossipSecretFile;
      enablePersistence = cfg.enablePersistence;
      openFirewall = true;
      settings = {
        interface = cfg.interface;
        gossip_port = cfg.gossipPort;
        peers = cfg.peers;
      };
    };

    fmf.services.vault-agent.services.wgautomesh = {
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
