{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.rkvm;
  parts = lib.splitString ":" cfg.address;
  port = lib.toInt (builtins.elemAt parts 1);
in {
  options.fmf.desktop.addons.rkvm = with types; {
    enableServer =
      mkBoolOpt false "Whether to enable rkvm in the desktop environment.";
    enableClient =
      mkBoolOpt false "Whether to enable rkvm in the desktop environment.";
    address =
      mkOpt str "0.0.0.0:5258"
      "What IP and Port to listen on or the IP:Port of the server";
    switch-keys = mkOpt str ''["left-alt", "left-ctrl"]'' "Switch Keys";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/rkvm"
      "The Vault path to the KV containing the rkvm secrets.";
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
  };
  config = mkMerge [
    (mkIf cfg.enableServer {
      environment.systemPackages = with pkgs; [rkvm];

      networking.firewall = {
        # enable = true;
        allowedTCPPorts = [
          port
        ];
      };
      systemd.services.rkvm = {
        description = "RKVM Service";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${pkgs.rkvm}/bin/rkvm-server /var/lib/rkvm/server.toml";
          # Add other service configurations as needed
        };

        preStart = ''
          mkdir -p /var/lib/rkvm
          cp /tmp/detsys-vault/cert.crt /var/lib/rkvm/
          cp /tmp/detsys-vault/cert.key /var/lib/rkvm/
          cat > /var/lib/rkvm/server.toml << EOF
          # TOML configuration goes here
          listen = "${cfg.address}"
          # See `switch-keys.md` in the repository root for the list of all possible keys.
          switch-keys = ${cfg.switch-keys}
          # Whether switch key presses should be propagated on the server and its clients.
          # Optional, defaults to true.
          # propagate-switch-keys = true
          certificate = "/var/lib/rkvm/cert.crt"
          key = "/var/lib/rkvm/cert.key"

          # This is to prevent malicious clients from connecting to the server.
          # Make sure this matches your client's config.
          #
          # Change this to your own value before deploying rkvm.
          password = "$RKVM_PASS"
          EOF
          chmod 600 /var/lib/rkvm/server.toml
        '';
      };
    })
    (mkIf cfg.enableClient {
      environment.systemPackages = with pkgs; [rkvm];

      systemd.services.rkvm = {
        description = "RKVM Service";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          RestartSec = 120;
          Delegate = "yes";
          KillMode = "process";
          LimitCORE = "infinity";
          TasksMax = "infinity";
          TimeoutStartSec = 0;
          LimitNOFILE = 999999;
          Restart = "always";
          ExecStart = "${pkgs.rkvm}/bin/rkvm-client /var/lib/rkvm/client.toml";
          # Add other service configurations as needed
        };

        preStart = ''
          mkdir -p /var/lib/rkvm
          cp /tmp/detsys-vault/cert.crt /var/lib/rkvm/
          cat > /var/lib/rkvm/client.toml << EOF
          server = "${cfg.address}"
          certificate = "/var/lib/rkvm/cert.crt"

          # This is to prevent malicious clients from connecting to the server.
          # Make sure this matches your server's config.
          #
          # Change this to your own value before deploying rkvm.
          password = "$RKVM_PASS"
          EOF
          chmod 600 /var/lib/rkvm/client.toml
        '';
      };
    })
    5258
    {
      fmf.services.vault-agent = {
        services = {
          "rkvm" = {
            settings = {
              # replace with the address of your vault
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
              environment.templates = {
                rkvm = {
                  text = ''
                    {{ with secret "${cfg.vault-path}" }}
                    RKVM_PASS={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password  }}{{ else }}{{ .Data.data.password }}{{ end }}
                    {{ end }}
                  '';
                };
              };
              file = {
                files = {
                  "cert.crt" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.cert }}{{ else }}{{ .Data.data.cert }}{{ end }}{{ end }}'';
                    permissions = "0600";
                    change-action = "restart";
                  };
                  "cert.key" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.key }}{{ else }}{{ .Data.data.key }}{{ end }}{{ end }}'';
                    permissions = "0600";
                    change-action = "restart";
                  };
                };
              };
            };
          };
        };
      };
    }
  ];
}
