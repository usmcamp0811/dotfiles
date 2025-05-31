{ lib
, writeText
, writeShellApplication
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

  # version = "1.28.5+k0s.0";
  # hash = "sha256-9XJAHnPeMGFpQwesVf5r3VKp8mLufbj9uBzltMIQVl4=";
  # version = "1.32.2+k0s.0";
  # hash = "sha256-pMYqtOrjvDa/LPpDH56pkH7dMDQ+MltKmkJhCqfkPy8=";
  version = "1.32.3+k0s.0";
  hash = "sha256-4GVUwPvBF8d5JnPlNil8Pnku78sgRXKJ71sCiUzoWy8=";
  # version = "1.31.6+k0s.0";
  # hash = "sha256-By3zQuQmBDqglTc4j+LFZfFEMLioJEa1mReuvxAnRXQ=";
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
  };

  new-meta = with lib; {
    description = "k0s - The Zero Friction Kubernetes";
    license = licenses.asl20;
    maintainers = with maintainers; [ jakehamilton ];
  };
in
override-meta new-meta k0s
