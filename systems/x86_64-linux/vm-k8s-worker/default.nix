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

    vcpu = 6;
    mem = 8192;
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
      fullName = "K8s Worker Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/vm-k8s-worker/role-id";
          secret-id = "/var/lib/vault/vm-k8s-worker/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };

      k3s = {
        enable = true;
        role = "agent";
        clusterInit = false;
        serverAddr = "192.169.1.50";
        config = {
          node-name = "vm-k8s-worker";
        };
      };
    };
  };

  # Open necessary ports for k8s worker
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      10250 # Kubelet
      7946  # MetalLB memberlist
    ];
    allowedTCPPortRanges = [
      { from = 30000; to = 32767; } # NodePort services
    ];
    allowedUDPPorts = [
      7946  # MetalLB memberlist
    ];
  };

  system.stateVersion = "23.05";
}
