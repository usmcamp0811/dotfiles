{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.fmf; {
  # Set snowfallorg user name for home-manager
  home-manager.users.admin.snowfallorg.user.name = "admin";

  # MicroVMs don't use bootloaders - booted directly by QEMU
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  ############################################################
  # MicroVM configuration
  ############################################################
  microvm = {
    hypervisor = "qemu";
    # Shares and the writable store overlay come from ./storage.nix (fmf.host), not from here.

    vcpu = 4;
    mem = 4096;
    socket = "control.socket";
  };

  ############################################################
  # Networking: the NIC name, address, gateway, DNS and tap come from ./host.nix (fmf.host.network.derive)
  ############################################################
  services.resolved.enable = false;

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system configuration
  ############################################################
  fmf = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "Gitea Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/vm-gitea/role-id";
          secret-id = "/var/lib/vault/vm-gitea/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };

      gitea = {
        enable = true;
        appName = "AI Campground Gitea";
        domain = "git.lan.aicampground.com";
        port = 3000;
        httpPort = 8445;
        sshPort = 22022;
        databaseType = "sqlite3";
        repositoryRoot = "/var/lib/gitea/repositories";
        stateDir = "/var/lib/gitea";
        disableRegistration = false;
        enableLFS = true;
        enableActions = true;
      };
    };
  };

  system.stateVersion = "23.05";
}
