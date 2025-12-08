# Impermanence configuration for blue-ridge router
# Root filesystem is tmpfs (wiped on boot)
# Only /nix and /persist survive reboots
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable impermanence
  environment.persistence."/persist/system" = {
    hideMounts = true;

    directories = [
      # System directories
      "/var/log"
      "/var/lib/systemd"
      "/var/lib/nixos"

      # Network state
      "/var/lib/kea" # DHCP leases
      "/var/lib/unbound" # DNS state and DNSSEC root key
      "/var/lib/fail2ban" # fail2ban state
      "/etc/NetworkManager/system-connections" # If using NetworkManager

      # SSH host keys
      "/etc/ssh"
    ];

    files = [
      # Machine ID (must be a file, not directory)
      "/etc/machine-id"

      # systemd random seed
      "/var/lib/systemd/random-seed"

      "/var/lib/crystal-forge-agent/agent.key"
    ];

    users.admin = {
      directories = [
        "Downloads"
        "Documents"
        ".ssh"
        ".cache"
        ".local"
        {
          directory = ".gnupg";
          mode = "0700";
        }
      ];
      files = [
        ".bash_history"
        ".zsh_history"
      ];
    };
  };

  # Create necessary directories on boot
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root -"
    "d /persist/system 0755 root root -"
    "d /persist/home 0755 root root -"
    "d /persist/home/admin 0700 admin users -"
  ];

  # Bind mount home directories to /persist
  fileSystems."/home/admin" = {
    device = "/persist/home/admin";
    options = ["bind" "noatime"];
    depends = ["/persist"];
  };

  # Ensure users don't accidentally write to ephemeral home
  systemd.services.setup-ephemeral-home = {
    description = "Setup ephemeral home directory structure";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    script = ''
      # Ensure /home exists
      mkdir -p /home
      # Set restrictive permissions on ephemeral /home
      chmod 755 /home
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Warnings about impermanence
  warnings =
    if config.environment.persistence ? "/persist/system"
    then []
    else [
      ''
        Impermanence is configured but environment.persistence is not available.
        Make sure the impermanence module is imported.
      ''
    ];

  # Helpful script to show what's persisted
  environment.systemPackages = [
    (pkgs.writeScriptBin "show-persisted" ''
      #!${pkgs.bash}/bin/bash
      echo "=== Persisted Directories ==="
      echo ""
      echo "System directories:"
      find /persist/system -maxdepth 2 -type d 2>/dev/null | head -20
      echo ""
      echo "Home directories:"
      find /persist/home -maxdepth 3 -type d 2>/dev/null
      echo ""
      echo "Disk usage:"
      ${pkgs.coreutils}/bin/du -sh /persist/* 2>/dev/null
    '')

    (pkgs.writeScriptBin "check-ephemeral" ''
      #!${pkgs.bash}/bin/bash
      echo "=== Ephemeral Root Status ==="
      echo ""
      echo "Root filesystem (should be tmpfs):"
      ${pkgs.util-linux}/bin/findmnt -n -o FSTYPE /
      echo ""
      echo "Root usage:"
      ${pkgs.coreutils}/bin/df -h / | tail -1
      echo ""
      echo "Persistent usage:"
      ${pkgs.coreutils}/bin/df -h /persist | tail -1
      echo ""
      echo "Files in ephemeral root (excluding mounts):"
      ${pkgs.findutils}/bin/find / -maxdepth 1 -not -path / -not -path /nix -not -path /persist -not -path /boot -not -path /home -not -path /proc -not -path /sys -not -path /dev -not -path /run 2>/dev/null
    '')
  ];

  # Ensure the system can boot without /persist existing
  # This is important for first-time installation
  boot.initrd.systemd.enable = false; # Use traditional stage-1
}
