{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
# TODO: Add Remote Logging Server options
mkStigModule {
  inherit config;
  name = "audit_log_offloading";
  srgList = [ "SRG-OS-000051-GPOS-00024" "SRG-OS-000269-GPOS-00103" ];
  cciList = [ "CCI-000154" "CCI-001665" ];
  stigConfig = {
    environment.systemPackages = [ pkgs.syslogng ];
    services.syslog-ng.enable = true;
    services.syslog-ng.extraConfig = ''
      source s_local { system(); internal(); };

      destination d_network {
        syslog("<remote-logging-server>" port(<port>));
      };

      log { source(s_local); destination(d_network); };
    '';
  };
}
