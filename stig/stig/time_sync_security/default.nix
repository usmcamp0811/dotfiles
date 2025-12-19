{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "time_sync_security";
  srgList = [
    "SRG-OS-000355-GPOS-00143"
    "SRG-OS-000359-GPOS-00146"
    "SRG-OS-000785-GPOS-00250"
    "SRG-OS-000362-GPOS-00149"
    "SRG-OS-000363-GPOS-00150"
  ];
  cciList =
    [ "CCI-004923" "CCI-001890" "CCI-004922" "CCI-004926" "CCI-003980" ];
  stigConfig = {
    # Set Approved Time Servers
    networking.timeServers =
      [ "tick.usnogps.navy.mil" "tock.usnogps.navy.mil" ];

    # Enable System Time Sync
    # TODO: Put this back figure out how to override
    services.timesyncd.enable = mkForce true;

    # Enforce Regular Time Sync (Max Poll Interval: 60 sec)
    services.timesyncd.extraConfig = ''
      PollIntervalMaxSec=60
    '';

    # Restrict Software Installation to Root and Wheel Users Only
    nix.settings.allowed-users = [ "root" "@wheel" ];

    # Configuration Monitoring - Notify Admins on Unauthorized Changes
    # TODO: Update with real email
    systemd.services.config-monitor = {
      enable = true;
      script = ''
        #!/bin/sh
        if [ "$(git -C /etc/nixos diff --quiet)" ]; then
          echo "Unauthorized config change detected" | mail -s "NixOS Config Change Alert" admin@example.com
        fi
      '';
      serviceConfig = { Type = "oneshot"; };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
