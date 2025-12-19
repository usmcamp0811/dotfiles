{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "disk_encryption";
  srgList = [
    "SRG-OS-000185-GPOS-00079"
    "SRG-OS-000404-GPOS-00183"
    "SRG-OS-000405-GPOS-00184"
    "SRG-OS-000780-GPOS-00240"
  ];
  stigConfig = {
    # TODO: Handle this and point to real drives 
    # boot.initrd.luks.devices = {
    #   root = {
    #     device = "/dev/sda2";
    #     preLVM = true;
    #   };
    # };

    systemd.services.check-encryption = {
      description =
        "Verify all persistent partitions are encrypted (LUKS or ZFS)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          FAILED=0

          # Check LUKS partitions
          for dev in $(lsblk -ndo NAME,TYPE | awk '$2 == "crypt" {print "/dev/"$1}'); do
            if ! blkid "$dev" | grep -q 'TYPE="crypto_LUKS"'; then
              echo "ERROR: $dev is not encrypted with LUKS." >&2
              FAILED=1
            fi
          done

          # Check ZFS encryption
          if command -v zfs >/dev/null; then
            for dataset in $(zfs list -H -o name,encryption | awk '$2 != "off" {print $1}'); do
              if [ -z "$dataset" ]; then
                echo "ERROR: $dataset is not encrypted." >&2
                FAILED=1
              fi
            done
          fi

          if [ "$FAILED" -eq 1 ]; then
            exit 1
          fi

          exit 0
        '';
      };
    };
  };
}
