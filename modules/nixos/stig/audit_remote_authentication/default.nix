mkStigModule {
  inherit config;
  name = "audit_remote_authentication";
  srgList = [ "SRG-OS-000051-GPOS-00024" ];
  cciList = [ "CCI-000154" ];
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
