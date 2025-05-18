{ lib
, pkgs
, ...
}:
with lib.campground;
wrapWithRMF {
  pkg = pkgs.campground.example-flask-app;

  rmfMeta = {
    approved = false;
    controls = {
      "AC-17" = {
        status = "met";
        config = {
          networking.firewall.enable = true;
        };
        srg = [ "SRG-APP-000516" ];
        cci = [ "CCI-000366" ];
      };

      "CM-2" = {
        status = "waived";
        justification = "Manual configuration accepted in dev.";
        config = {
          nix.settings.warn-dirty = true;
        };
        srg = [ "SRG-APP-000142" ];
        cci = [ "CCI-000366" ];
      };
    };
    poc = "DevSecOps <devsecops@example.mil>";
    lastReviewed = "2025-08-15";
  };
}
