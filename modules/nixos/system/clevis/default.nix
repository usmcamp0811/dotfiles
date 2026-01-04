{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.clevis;

  # Render a list of { device, name } into shell lines.
  tangUnlockCommands = concatStringsSep "\n" (
    map
    (d: ''
      echo "[clevis] Tang unlock: ${escapeShellArg d.device} -> ${escapeShellArg d.name}"
      ${pkgs.clevis}/bin/clevis luks unlock -d ${escapeShellArg d.device} -n ${escapeShellArg d.name}
    '')
    cfg.tang.devices
  );

  keyfileUnlockCommands = ''
    set -euo pipefail

    echo "[clevis] Fetching encrypted keyfile from: ${escapeShellArg cfg."keyfile-url"}"
    enc="$(${pkgs.curl}/bin/curl -s ${escapeShellArg cfg."keyfile-url"})"

    echo "$enc" | ${pkgs.clevis}/bin/clevis decrypt > ${escapeShellArg cfg.luksKeyPath}

    ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
      --key-file ${escapeShellArg cfg.luksKeyPath} \
      ${escapeShellArg cfg.luksDevice} \
      ${escapeShellArg cfg.luksName}
  '';

  tangUnlockBody = ''
    set -euo pipefail
    echo "[clevis] Tang mode enabled; unlocking ${toString (length cfg.tang.devices)} device(s)"
    ${tangUnlockCommands}
  '';

  unlockScript = pkgs.writeShellScript "fmf-clevis-unlock" (
    if cfg.tang.enable
    then tangUnlockBody
    else keyfileUnlockCommands
  );

  # Which cryptsetup units must *not* start until we've attempted clevis unlock?
  #
  # In your setup, disko typically creates a LUKS mapping name like "crypted".
  # If you set cfg.luksMappingNames = [ "crypted" ]; then this will gate that unit.
  cryptsetupUnits =
    map (name: "systemd-cryptsetup@${name}.service") cfg.luksMappingNames;
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis.";

    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";

    "keyfile-url" =
      mkOpt str "http://key-server:8080/zfs-keyfile"
      "The URL for the Clevis encrypted Keyfile";

    luksDevice = mkOpt str "/dev/nvme0n1p2" "Default LUKS block device to open (non-Tang mode).";
    luksName = mkOpt str "luks" "Default mapper name to use with cryptsetup (non-Tang mode).";
    luksKeyPath = mkOpt str "/luks.key" "Where to write the decrypted key inside initrd (non-Tang mode).";

    # IMPORTANT: the *crypttab mapping names* (systemd unit instance names) to gate.
    # For disko layouts this is often "crypted".
    luksMappingNames =
      mkOpt (listOf str) ["crypted"]
      "List of LUKS mapping names to gate (creates dependencies for systemd-cryptsetup@<name>.service).";

    tang = {
      enable = mkBoolOpt false ''
        If true, unlock LUKS devices using the Clevis Tang token stored in the LUKS header (keyslot/token),
        instead of downloading/decrypting a remote keyfile.
      '';

      devices =
        mkOpt (listOf (submodule ({...}: {
          options = {
            device = mkOpt str "/dev/nvme0n1p2" "Block device containing the LUKS header with a Tang binding.";
            name = mkOpt str "luks" "Mapper name to create for this device.";
          };
        }))) [
          {
            device = "/dev/nvme0n1p2";
            name = "luks";
          }
        ] "List of LUKS devices to unlock via Tang when tang.enable is true.";
    };

    initrdSsh = {
      enable = mkBoolOpt true "Enable initrd SSH for remote unlock/debug.";
      port = mkOpt types.port 22 "Initrd SSH port.";
      shell = mkOpt str "/bin/cryptsetup-askpass" "Initrd SSH shell.";
      authorizedKeys = mkOpt (listOf str) [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
      ] "Authorized keys for initrd SSH.";
      hostKeys = mkOpt (listOf path) [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
      ] "Host keys for initrd SSH.";
    };

    initrdKernelModules =
      mkOpt (listOf str) ["iwlwifi" "igc" "nfsv4"]
      "Extra initrd kernel modules to make networking/NFS work in stage-1.";

    # Systemd-initrd networking knobs (so network-online.target can actually be reached).
    initrdNetwork = {
      interfaceMatch = mkOpt str "en*" "Interface name pattern for initrd DHCP (e.g. en*, eth*, eno1).";
      waitOnline = mkOpt bool true "Whether initrd should wait for network-online.target.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis];

    ##########################################################################
    # Initrd (systemd stage-1) networking configuration
    ##########################################################################
    boot.initrd.network.enable = true;

    # Explicitly configure systemd-networkd in initrd so DHCP comes up.
    boot.initrd.systemd.network.enable = true;
    boot.initrd.systemd.network.wait-online.enable = cfg.initrdNetwork.waitOnline;

    boot.initrd.systemd.network.networks."10-initrd-dhcp" = {
      matchConfig.Name = cfg.initrdNetwork.interfaceMatch;
      networkConfig.DHCP = "yes";
      networkConfig.IPv6AcceptRA = true;
      linkConfig.RequiredForOnline = "routable";
    };

    ##########################################################################
    # Ensure required binaries exist inside the initrd
    ##########################################################################
    boot.initrd.systemd.storePaths = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.clevis
      pkgs.cryptsetup
    ];

    ##########################################################################
    # Clevis unlock as an initrd systemd unit, gated ahead of cryptsetup
    ##########################################################################
    boot.initrd.systemd.services."fmf-clevis-unlock" = {
      description = "FMF Clevis unlock (initrd)";

      # Run when initrd comes up, *and* tie it to cryptsetup units so it runs first.
      wantedBy = ["initrd.target"];

      # Make sure we have network before we try Tang or download keyfile.
      wants = ["network-online.target"];
      after = ["network-online.target"];

      # This is the key: run BEFORE cryptsetup units and make cryptsetup require us.
      before = cryptsetupUnits;
      requiredBy = cryptsetupUnits;

      unitConfig.DefaultDependencies = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${unlockScript}";
      };
    };

    ##########################################################################
    # Optional initrd SSH (kept)
    ##########################################################################
    boot.initrd.network.ssh = mkIf cfg.initrdSsh.enable {
      enable = true;
      port = cfg.initrdSsh.port;
      shell = cfg.initrdSsh.shell;
      authorizedKeys = cfg.initrdSsh.authorizedKeys;
      hostKeys = cfg.initrdSsh.hostKeys;
    };

    ##########################################################################
    # Modules + DHCP kernel param (kept)
    ##########################################################################
    boot.initrd.availableKernelModules = cfg.initrdKernelModules;
    boot.kernelParams = ["ip=dhcp"];
  };
}
