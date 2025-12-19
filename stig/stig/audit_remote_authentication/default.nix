{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
# TODO: add options for remote-loggin-server and port
mkStigModule {
  inherit config;
  name = "audit_remote_authentication";
  srgList = [
    "SRG-OS-000051-GPOS-00024"
    "SRG-OS-000342-GPOS-00133"
    "SRG-OS-000479-GPOS-00224"
  ];
  cciList = [ "CCI-000154" "CCI-001851" ];
  stigConfig = {
    services.syslog-ng.extraConfig = ''
      destination d_network {
        syslog(
          "<remote-logging-server>" port(<port>)
          transport(tls)
          tls(
            cert-file("/var/syslog-ng/certs.d/certificate.crt")
            key-file("/var/syslog-ng/certs.d/certificate.key")
            ca-file("/var/syslog-ng/certs.d/cert-bundle.crt")
            peer-verify(yes)
          )
        );
      };

      log { source(s_local); destination(d_network); };
    '';
  };
}
