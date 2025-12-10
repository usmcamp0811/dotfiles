{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.campground; {
  # MicroVM configuration
  microvm = {
    # Use microvm as the hypervisor (lightweight, fast boot)
    hypervisor = "qemu";

    # Share the host's Nix store to save disk space
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      # Add writable host directory mounts here
      {
        proto = "virtiofs";
        tag = "vault-agent";
        source = "/var/lib/vault/vault";
        mountPoint = "/var/lib/vault/vault";
      }
      {
        proto = "virtiofs";
        tag = "var-nix";
        source = "/nix/var/nix"; # Share actual files, not symlinks
        mountPoint = "/nix/var/nix";
      }
    ];

    # Networking - TAP interface bridged to host network
    interfaces = [
      {
        type = "tap";
        id = "vm-vault";
        mac = "02:00:00:00:00:10"; # Static MAC for consistent DHCP
      }
    ];

    # Resources
    vcpu = 2;
    mem = 8047; # ~2GB RAM (avoid exactly 2048 due to QEMU bug)

    # Boot configuration
    socket = "control.socket";

    # Volumes for persistent data
    volumes = [
      {
        image = "vault-data.img";
        mountPoint = "/var/lib/vault";
        size = 10240; # 10GB for vault data
      }
    ];
  };

  networking.interfaces.eth0.useDHCP = true;

  # Force use of host's nix daemon (store is read-only)
  nix.settings = {
    store = "/nix/store";
    state-dir = "/nix/var/nix";
  };

  # Basic system configuration
  campground = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "Vault Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/vault/role-id";
            secret-id = "/var/lib/vault/vault/secret-id";
          };
        };
      };
      vault = {
        enable = true;
        ui = true;
        auto-unseal = true;
        storage = {
          backend = "raft";
          config = ''
            node_id = "vault-node-vm"
          '';
        };
        settings = ''
          cluster_addr = "http://vault:8201"
          api_addr = "http://vault:8200"
        '';

        policies =
          builtins.foldl'
          (policies: file:
            policies
            // {
              "${snowfall.path.get-file-name-without-extension file}" = file;
            })
          {}
          (builtins.filter (snowfall.path.has-file-extension "hcl")
            (builtins.map
              (path:
                ../daly/vault/policies
                + "/${
                  builtins.baseNameOf (builtins.unsafeDiscardStringContext path)
                }")
              (snowfall.fs.get-files ../daly/vault/policies)));
      };
      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };
  };

  system.stateVersion = "23.05";
}
