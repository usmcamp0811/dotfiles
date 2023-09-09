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
  pname = "k0s";

  owner = "k0sproject";
  repo = pname;
  description = "k0s - The Zero Friction Kubernetes";

  version = "1.27.4+k0s.0";
  hash = "sha256-JmaCRTMU3qsVu/AzyDHpSwv0j9NPxs11WiRbZYqAPHs=";
  # version = "1.26.3+k0s.0";
  # hash = "sha256-JmaCRTMU3qsVu/AzyDHpSwv0j9NPxs11WiRbZYqAPHs=";

  # Build a derivation from binary releases hosted on GitHub
  k0s = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = pkgs.fetchurl {
      url = "https://github.com/${owner}/${repo}/releases/download/v${version}/${repo}-v${version}-amd64";
      inherit hash;
    };
    phases = [ "installPhase" ];
    installPhase = ''
      install -m 555 -D -- "$src" "$out"/bin/'${pname}'
    ''; # Shell completions could be added here.

    # Metadata required for a real package
    # meta = with lib; {
    #   inherit description;
    #   license = licenses.asl20;
    #   homepage = "https://k0sproject.io";
    #   platforms = [ "x86_64-linux" ]; # ARM 32/64 binary releases also available.
    # };
  };

  # # Some minimal sample config
  # k0sConfig = pkgs.writeText "${pname}.json" (builtins.toJSON {
  #   apiVersion = "k0s.k0sproject.io/v1beta1";
  #   kind = "ClusterConfig";
  #   metadata.name = pname;
  #   spec.network.provider = "kuberouter";
  # });
  new-meta = with lib; {
    description = "k0s - The Zero Friction Kubernetes";
    license = licenses.asl20;
    maintainers = with maintainers; [ jakehamilton ];
  };
in
# {
#   # If k0s should be in the PATH:
#   # environment.systemPackages = [ k0s ];
#
# }
override-meta new-meta k0s
