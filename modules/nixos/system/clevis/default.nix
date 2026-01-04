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

  keyfilePostCommands = ''
    set -euo pipefail

    echo "[clevis] Fetching encrypted keyfile from: ${escapeShellArg cfg."keyfile-url"}"
    enc="$(${pkgs.curl}/bin/curl -s ${escapeShellArg cfg."keyfile-url"})"

    echo "$enc" | ${pkgs.clevis}/bin/clevis decrypt > ${escapeShellArg cfg.luksKeyPath}

    ${pkgs.cryptsetup}/bin/cryptsetup luksOpen \
      --key-file ${escapeShellArg cfg.luksKeyPath} \
      ${escapeShellArg cfg.luksDevice} \
      ${escapeShellArg cfg.luksName}
  '';

  tangPostCommands = ''
    set -euo pipefail

    echo "[clevis] Tang mode enabled; unlocking ${toString (length cfg.tang.devices)} device(s)"
    ${tangUnlockCommands}
  '';
in {
  options.fmf.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis.";

    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";

    # Keep current default behavior (remote encrypted keyfile -> clevis decrypt -> cryptsetup luksOpen)
    "keyfile-url" =
      mkOpt str "http://key-server:8080/zfs-keyfile"
      "The URL for the Clevis encrypted Keyfile";

    luksDevice = mkOpt str "/dev/nvme0n1p2" "Default LUKS block device to open (non-Tang mode).";
    luksName = mkOpt str "luks" "Default mapper name to use with cryptsetup (non-Tang mode).";
    luksKeyPath = mkOpt str "/luks.key" "Where to write the decrypted key inside initrd (non-Tang mode).";

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
      enable = mkBoolOpt true "Enable initrd SSH for remote unlock/debug (matches current behavior).";
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
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [clevis];

    boot.initrd.network = {
      enable = true;

      # Define once; choose behavior based on tang.enable
      postCommands =
        if cfg.tang.enable
        then tangPostCommands
        else keyfilePostCommands;

      ssh = mkIf cfg.initrdSsh.enable {
        enable = true;
        port = cfg.initrdSsh.port;
        shell = cfg.initrdSsh.shell;
        authorizedKeys = cfg.initrdSsh.authorizedKeys;
        hostKeys = cfg.initrdSsh.hostKeys;
      };
    };

    boot.initrd.availableKernelModules = cfg.initrdKernelModules;
    boot.kernelParams = ["ip=dhcp"];
  };
}
