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
      fullName = "K8s Control Plane Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/vm-k8s-control/role-id";
          secret-id = "/var/lib/vault/vm-k8s-control/secret-id";
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
        role = "server";
        clusterInit = true;
        serverAddr = "192.169.1.50";
        config = {
          disable = ["servicelb" "traefik"];
          cluster-init = true;
          tls-san = ["192.169.1.50" "k8s-control.lan.aicampground.com"];
          node-name = "vm-k8s-control";
        };
      };
    };
  };

  # Open necessary ports for k8s
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      6443 # Kubernetes API
      10250 # Kubelet
      2379 # etcd client
      2380 # etcd peer
    ];
  };

  system.stateVersion = "23.05";
}
