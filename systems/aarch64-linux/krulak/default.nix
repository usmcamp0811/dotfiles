{inputs, lib, pkgs, modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    initrd.availableKernelModules = ["nvme" "usbhid" "usb_storage" "xhci_pci"];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = false;
    };
  };
  hardware.enableRedistributableFirmware = true;

  # Standalone bootstrap: no server suite, private cache, or Vault credentials.
  crystal-forge.stig-presets.off.enable = true;
  fmf.nix.enable = false;
  nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = ["nix-command" "flakes"];
  environment.systemPackages = [pkgs.git];

  networking = {
    useNetworkd = true;
    useDHCP = true;
    firewall.enable = true;
  };
  services.resolved.enable = true;

  fmf.user = {
    name = "admin";
    fullName = "Example Administrator";
    extraGroups = ["wheel"];
    initialPassword = null;
  };
  # Supply your own public key in a downstream host config before installing.
  users.users.admin.openssh.authorizedKeys.keys = [];
  home-manager.users.admin = {
    snowfallorg.user.name = "admin";
    home.stateVersion = "26.05";
    home.sessionVariables.EDITOR = lib.mkForce "${pkgs.nano}/bin/nano";
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    hostKeys = [{path = "/persist/system/etc/ssh/ssh_host_ed25519_key"; type = "ed25519";}];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  systemd.services.sshd-keygen.unitConfig.RequiresMountsFor = "/persist";
  systemd.services.sshd.unitConfig.RequiresMountsFor = "/persist";

  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = ["/var/lib/nixos" "/var/lib/systemd" "/var/log"];
    files = ["/etc/machine-id"];
  };

  system.stateVersion = "26.05";
}
