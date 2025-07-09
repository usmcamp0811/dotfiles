{
  options,
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.nix;
  substituters-submodule = types.submodule ({...}: {
    options = with types; {
      key =
        mkOpt (nullOr str) null "The trusted public key for this substituter.";
    };
  });
in {
  options.campground.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt package pkgs.nixVersions.stable "Which nix package to use.";
    additional-authorized-users =
      mkOpt (listOf str) [] "List of authorized users";

    default-substituter = {
      url = mkOpt str "https://cache.nixos.org" "The url for the substituter.";
      key =
        mkOpt str
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "The trusted public key for the substituter.";
    };

    extra-substituters =
      mkOpt (attrsOf substituters-submodule) {}
      "Extra substituters to configure.";

    role-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/netrc"
      "The Vault path to the KV containing the KVs that are for a properly formated netrc file text";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    assertions =
      mapAttrsToList
      (name: value: {
        assertion = value.key != null;
        message = "campground.nix.extra-substituters.${name}.key must be set";
      })
      cfg.extra-substituters;
    environment.systemPackages = with pkgs; [
      campground.nixos-revision
      (campground.nixos-hosts.override {
        hosts = inputs.self.nixosConfigurations;
      })
      deploy-rs
      nixfmt-classic
      nix-index
      nix-prefetch-git
      nix-output-monitor
      flake-checker
    ];
    systemd.services.nix-daemon.serviceConfig.Environment = "NETRC=/var/lib/nixos/netrc";

    systemd.services.nix-daemon = {
      environment = {
        NETRC = "/var/lib/nixos/netrc";
      };
    };

    # TODO: Figure out if I can just use it straigh from the /tmp/detsys-vault/netrc location
    systemd.services.copyNETRC = {
      description = "Copy the NETRC file to the correct spot";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/nixos";
        ExecStart = "${pkgs.coreutils}/bin/cp /tmp/detsys-vault/netrc /var/lib/nixos/netrc";
        before = ["nix-daemon.service"];
      };
      wantedBy = ["multi-user.target"];
    };
    # In your nixos configuration (probably in modules/nixos/nix/ or similar)
    nix = let
      users =
        ["root" config.campground.user.name]
        ++ cfg.additional-authorized-users
        ++ (optional config.campground.services.hydra.enable "hydra")
        ++ (optional config.campground.services.nixery.enable "nixery");
    in {
      package = cfg.package;
      registry.nixpkgs.to = lib.mkForce {
        type = "path";
        path = inputs.nixpkgs;
      };

      settings =
        {
          experimental-features = "nix-command flakes";
          fallback = true;
          http-connections = 50;
          warn-dirty = false;
          log-lines = 50;
          sandbox = "relaxed";
          auto-optimise-store = true;
          trusted-users = users;
          allowed-users = users;
          netrc-file = "/var/lib/nixos/netrc";
          extra-sandbox-paths = ["/var/lib/nixos/netrc"];

          substituters =
            # [ cfg.default-substituter.url ]
            # ++
            mapAttrsToList (name: _value: name) cfg.extra-substituters;
          trusted-public-keys =
            # [ cfg.default-substituter.key ]
            # ++
            mapAttrsToList (_name: value: value.key) cfg.extra-substituters;
        }
        // (lib.optionalAttrs config.campground.tools.direnv.enable {
          keep-outputs = true;
          keep-derivations = true;
        });

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      # flake-utils-plus
      generateRegistryFromInputs = true;
      generateNixPathFromInputs = true;
      linkInputs = true;
    };
    campground.services.vault-agent.services.copyNETRC = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
      secrets = {
        file = {
          files = {
            "netrc" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.netrc }}{{ else }}{{ .Data.data.netrc }}{{ end }}{{ end }} '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
