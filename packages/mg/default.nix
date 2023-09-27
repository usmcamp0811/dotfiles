{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "mg";

  owner = "mg";
  repo = pname;
  description = "Brownbag";

  version = "0.0.1";
  # version = "1.26.3+k0s.0";
  # hash = "sha256-JmaCRTMU3qsVu/AzyDHpSwv0j9NPxs11WiRbZYqAPHs=";
  scriptContent = pkgs.writeText "mg" ''
    #!/bin/sh
    echo "Hello, this is the entrypoint script."
    ${pkgs.cowsay}/bin/cowsay "yut yut"
  '';

  # Build a derivation from binary releases hosted on GitHub
  mg = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    phases = [ "installPhase" ];
    buildPhase = ''
      echo "Hello World" > $out/lib/hello
      echo "Hello 2" > $out/lib/hello2
      echo "Good Bye World" > $out/lib/goodbye
      cp $scriptContent $out/bin/mg
    '';
    installPhase = ''
      chmod +x $out/bin/mg
    ''; # Shell completions could be added here.

  };

  new-meta = with lib; {
    description = "Browngbag";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt ];
  };
in
# {
#   # If k0s should be in the PATH:
#   # environment.systemPackages = [ k0s ];
#
# }
override-meta new-meta mg
