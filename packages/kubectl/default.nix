{ stdenv, fetchurl, installShellFiles }:
let
  version = "1.27.9";
  sources = {
    x86_64-linux = fetchurl {
        url = "https://dl.k8s.io/release/v${version}/bin/linux/amd64/kubectl";
        sha256 =
          "d0caae91072297b2915dd65f6ef3055d27646dce821ec67d18da35ba9a8dc85b";
      };
    x86_64-darwin = fetchurl {
        url = "https://dl.k8s.io/release/v${version}/bin/darwin/amd64/kubectl";
        sha256 =
          "0b2b965f471768b68d7a06deb85d2d2202551db5cc62a7100bb8c309e636a717";
      };
    aarch64-darwin = fetchurl {
        url = "https://dl.k8s.io/release/v${version}/bin/darwin/arm64/kubectl";
        sha256 =
          "a5dd031329a357e4c06fc6404a5601773bba9ada075a481ef1008a0e7aa885f5";
      };
  };
in stdenv.mkDerivation rec {
  inherit version;
  pname = "kubectl";
  src = sources.${stdenv.hostPlatform.system};

  dontUnpack = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    local name=$(stripHash $src)
    install -m755 -D $src $out/bin/$name
    installShellCompletion --cmd $name \
    --zsh <($out/bin/kubectl completion zsh)
  '';

  platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
}
