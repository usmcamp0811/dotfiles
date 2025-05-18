{ lib
, pkgs
, ...
}:
with lib.campground;
mkCompliantPackage {
  pkg = pkgs.campground.example-flask-app;

  rmfMeta = {
    approved = false;
    mustMeetControls = {
      "AC-17" = {
        status = "met";
      };
      "CM-2" = {
        status = "waived";
        justification = "Manual config approved for dev environment only.";
      };
    };
    poc = "DevSecOps <devsecops@example.mil>";
    lastReviewed = "2025-08-15";
  };

  knownCompliantControls = [ "AC-17" "CM-2" ]; # Fails if CM-2 omitted
}
