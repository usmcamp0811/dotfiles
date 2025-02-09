{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "config_security";
  srgList = [
    "SRG-OS-000363-GPOS-00150"
    "SRG-OS-000445-GPOS-00199"
    "SRG-OS-000446-GPOS-00200"
    "SRG-OS-000447-GPOS-00201"
    "SRG-OS-000480-GPOS-00227"
    "SRG-OS-000423-GPOS-00187"
    "SRG-OS-000420-GPOS-00186"
  ];
  cciList = [
    "CCI-001744"
    "CCI-002696"
    "CCI-002699"
    "CCI-002702"
    "CCI-003992"
    "CCI-000366"
    "CCI-002890"
    "CCI-002385"
  ];
  stigConfig = {
    # Install & Configure AIDE for Baseline Monitoring
    nixpkgs.overlays = [
      (final: prev: {
        aide = prev.aide.overrideAttrs (old: {
          configureFlags = (old.configureFlags or [ ])
            ++ [ "--sysconfdir=/etc" ];
        });
      })
    ];
    environment.systemPackages = [ pkgs.aide ];
    # TODO: This seems like it might need a real email
    environment.etc."aide.conf".text = ''
      # AIDE configuration settings
      database_out=file:/var/lib/aide/aide.db.new.gz
      database_in=file:/var/lib/aide/aide.db.gz
      verbose=5
      report_url=mailto:root@notareal.email
      ALLXTRAHASHES=sha512
    '';
    environment.etc."aide.conf".mode = "0444";

    services.cron.enable = true;
    services.cron.systemCronJobs = [
      "00 0 * * 0 root aide -c /etc/aide.conf --check | /bin/mail -s 'AIDE Integrity Check Run for ${config.networking.hostName}' root@notareal.email"
    ];

    # Enforce Digital Signature Verification for Software Installation
    nix.settings.require-sigs = true;

    # Require Reauthentication for Privilege Escalation
    security.sudo.extraConfig = ''
      Defaults timestamp_timeout=0
    '';
    security.sudo.wheelNeedsPassword = true;

    # Enforce Cryptographic Mechanisms for Nonlocal Maintenance (FIPS 140-3)
    services.openssh.macs = [ "hmac-sha2-512" "hmac-sha2-256" ];

    # Enable Firewall and Enforce Rate Limits for DoS Protection
    networking.firewall.enable = true;
    networking.firewall.extraCommands = ''
      ip46tables --append INPUT --protocol tcp --dport 22 --match hashlimit --hashlimit-name ssh_byte_limit --hashlimit-mode srcip --hashlimit-above 1000000b/second --jump nixos-fw-refuse
      ip46tables --append INPUT --protocol tcp --dport 80 --match hashlimit --hashlimit-name http_conn_limit --hashlimit-mode srcip --hashlimit-above 1000/minute --jump nixos-fw-refuse
      ip46tables --append INPUT --protocol tcp --dport 443 --match hashlimit --hashlimit-name https_conn_limit --hashlimit-mode srcip --hashlimit-above 1000/minute --jump nixos-fw-refuse
    '';
  };
}
