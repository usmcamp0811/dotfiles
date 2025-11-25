{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "wireless_bluetooth_audit_time";
  srgList = [
    "SRG-OS-000299-GPOS-00117"
    "SRG-OS-000481-GPOS-00481"
    "SRG-OS-000300-GPOS-00118"
    "SRG-OS-000326-GPOS-00126"
    "SRG-OS-000355-GPOS-00143"
  ];
  cciList = [ "CCI-001444" "CCI-002418" "CCI-001443" "CCI-002233" ];
  stigConfig = {
    # Disable Wireless
    networking.wireless.enable = false;

    # Disable Bluetooth
    hardware.bluetooth.enable = false;

    # Ensure auditd is enabled
    security.auditd.enable = true;
    security.audit.enable = true;

    # Enforce privilege escalation logging
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv"
      "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv"
    ];

    # Network Time Synchronization (NTP)
    services.ntp.enable = true;
    services.ntp.servers =
      [ "time.nist.gov" "time.google.com" "0.pool.ntp.org" "1.pool.ntp.org" ];
  };
}
