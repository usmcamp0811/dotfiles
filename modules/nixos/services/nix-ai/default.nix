{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.nix-ai;
  extraFlagsString = concatStringsSep " " cfg.extraFlags;
in {
  options.fmf.services.nix-ai = with types; {
    enable = mkBoolOpt false "Enable nix-ai;";

    package = mkOption {
      type = types.package;
      default = pkgs.textgen-nvidia;
      description = "The package to use for the custom service";
    };

    port = mkOption {
      type = types.int;
      default = 18084;
      description = "The port for nix-ai service.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags for the nix-ai service.";
    };

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/nix-ai"
      "The Vault path to the KV containing the KVs that are for each database";
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

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ textgen-nvidia ];

    users.users.nixai = {
      isNormalUser = false;
      isSystemUser = true;
      description = "NixAI System User";
      group = "nixai";
      extraGroups = [ "nixai" ];
      home = "/var/lib/nix-ai";
    };

    users.groups.nixai = { };

    systemd.services.nix-ai = {
      description = "NixAI Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        User = "nixai";
        Group = "nixai";
        WorkingDirectory = "/var/lib/nix-ai";
      };
      script = ''
        source /tmp/detsys-vault/hf_token
        ${cfg.package}/bin/textgen --model-dir /var/lib/nix-ai/models --listen --api --listen-port ${
          toString cfg.port
        } ${extraFlagsString}
      '';
    };
    system.activationScripts.createNixAI = ''
      mkdir -p /var/lib/nix-ai/models
      chown -R nixai:nixai /var/lib/nix-ai
    '';

    fmf.services.vault-agent.services.nix-ai = {
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

      secrets = {
        file = {
          files = {
            "hf_token" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                export HF_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.HF_TOKEN }}{{ else }}{{ .Data.data.HF_TOKEN }}{{ end }}'
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };

  };

}
