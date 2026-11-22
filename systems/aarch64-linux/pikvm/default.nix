{
  lib,
  pkgs,
  ...
}: {
  imports = [./hardware.nix];

  # PiKVM (kvmd) with its web UI behind nginx. Not a deployment: a Raspberry Pi 4 reference that evaluates.
  fmf.services.pikvm = {
    enable = true;
    hardwareVersion = "v2-hdmi-rpi4";
    user = "admin";
    nginx = {
      enable = true;
      httpPort = 80;
      httpsPort = 443;
      httpsEnabled = false; # enable after providing certificates
    };
    openFirewall = true;
  };

  # Standalone: no server suite, private cache, or Vault credentials. fmf.nix stays off because it adds
  # deploy-rs, every host's closure and a netrc sidecar; the Pi cache is listed here instead, so a stranger's
  # first build fetches the kernel rather than compiling it.
  crystal-forge.stig-presets.off.enable = true;
  fmf.nix.enable = false;
  nix.package = pkgs.nixVersions.stable;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    extra-substituters = ["https://nixos-raspberrypi.cachix.org"];
    extra-trusted-public-keys = ["nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="];
  };
  environment.systemPackages = [pkgs.git];

  networking = {
    hostName = "pikvm";
    useNetworkd = true;
    useDHCP = true;
    firewall.enable = true;
  };
  services.resolved.enable = true;

  fmf.user = {
    name = "admin";
    fullName = "PiKVM Administrator";
    extraGroups = ["wheel" "gpio" "video"];
    initialPassword = null;
  };
  # Supply your own public key in a downstream host config BEFORE installing: with no key and no password
  # nobody can log in.
  users.users.admin.openssh.authorizedKeys.keys = [];
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # fmf's shared home module otherwise sets EDITOR to the custom Neovim build, which drags ImageMagick into
  # the closure and compiles it.
  home-manager.users.admin = {
    snowfallorg.user.name = "admin";
    home.stateVersion = "26.05";
    home.sessionVariables.EDITOR = lib.mkForce "${pkgs.nano}/bin/nano";
  };

  system.stateVersion = "26.05";
}
