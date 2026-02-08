{ lib
, pkgs
, ...
}:
with lib.fmf;
wrapWithRMF {
  pkg = pkgs.fmf.example-flask-app;

  installModule =
    { config
    , pkgs
    , lib
    , ...
    }: {
      config = {
        # systemd.services.example-rmf-flask-app = {
        #   wantedBy = [ "multi-user.target" ];
        #   serviceConfig.ExecStart = "${pkgs.fmf.example-flask-app}/bin/example-flask-app";
        # };
        environment.systemPackages = [ pkgs.fmf.example-flask-app ];
      };
    };
  moduleOptions = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port for example service.";
    };
  };
  rmfMeta = {
    approved = false;
    controls = {
      AC-17 = {
        status = "met";
        config = {
          # networking.firewall.enable = true;
        };
        srg = [ "SRG-APP-000516" ];
        cci = [ "CCI-000366" ];
      };

      CM-2 = {
        status = "waived";
        justification = "Manual configuration accepted in dev.";
        config = {
          # nix.settings.warn-dirty = true;
        };
        srg = [ "SRG-APP-000142" ];
        cci = [ "CCI-000366" ];
      };
    };
    poc = "DevSecOps <devsecops@example.mil>";
    lastReviewed = "2025-08-15";
  };
}
