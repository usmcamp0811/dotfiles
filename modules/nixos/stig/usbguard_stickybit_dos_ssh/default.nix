{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "usbguard_stickybit_dos_ssh";
  srgList = [
    "SRG-OS-000114-GPOS-00059"
    "SRG-OS-000378-GPOS-00163"
    "SRG-OS-000690-GPOS-00140"
    "SRG-OS-000138-GPOS-00069"
    "SRG-OS-000142-GPOS-00071"
    "SRG-OS-000163-GPOS-00072"
    "SRG-OS-000990-GPOS-00072"
  ];
  cciList =
    [ "CCI-000778" "CCI-001958" "CCI-003959" "CCI-001090" "CCI-001095" ];
  stigConfig = {
    # TODO: generate rules based on actual devices
    # Enable USBGuard and configure rules
    services.usbguard.enable = true;
    services.usbguard.rules = ''
      # Example rules; generate rules based on actual devices
      allow id 1d6b:0001 serial "0000:00:01.2" name "UHCI Host Controller" hash "FRDEjz7OhdJbNjmJ8zityiNX/LuO+ovKC07I0bOFjao=" parent-hash "9+Zsfvo9IR/AEQ/Fn4mzdoPGk0rqpjku6uErfS09K4c=" with-interface 09:00:00 with-connect-type ""
      allow id 0627:0001 serial "28754-0000:00:01.2-1" name "QEMU USB Tablet" hash "5TyVK8wyL5GmiIbZV2Sf/ehIRMCP83miy4kOzG6O+2M=" parent-hash "FRDEjz7OhdJbNjmJ8zityiNX/LuO+ovKC07I0bOFjao=" with-interface 03:00:00 with-connect-type "unknown"
    '';

    # Set sticky bit on world-writable directories to prevent unauthorized access
    systemd.tmpfiles.rules =
      [ "d /tmp 1777 root root -" "d /var/tmp 1777 root root -" ];

    # Mitigate DoS by enabling TCP syncookies
    boot.kernel.sysctl = { "net.ipv4.tcp_syncookies" = 1; };

    # Enforce SSH timeout after 10 minutes of inactivity
    services.openssh.extraConfig = ''
      ClientAliveInterval 600
      ClientAliveCountMax 0
    '';
  };
}
