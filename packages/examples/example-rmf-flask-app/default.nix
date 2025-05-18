{ lib
, pkgs
, ...
}:
with lib.campground; let
  test-case = mkCompliantPackage {
    pkg = pkgs.campground.example-flask-app;

    rmfMeta = {
      approved = false;
      mustMeetControls = {
        "AC-17" = {
          status = "met";
        };
        "CM-2" = {
          # status = "met";
          status = "waived"; # causes failure
          justification = "Manual config approved for dev environment only.";
        };
      };
      poc = "DevSecOps <devsecops@example.mil>";
      lastReviewed = "2025-08-15";
    };

    # Uncomment this to force failure:
    # knownCompliantControls = ["AC-17"];

    # This will succeed:
    knownCompliantControls = [ "AC-17" "CM-2" ];
  };
in
test-case
