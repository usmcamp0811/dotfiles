{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, system
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;
  inherit system;

  description = "Netmaker UI";
  netmaker-ui = pkgs.buildNpmPackage rec {
    name = "netmaker-ui";
    version = "0.19.0";
    src = pkgs.fetchFromGitHub {
      owner = "gravitl";
      repo = "netmaker-ui";
      rev = "v${version}";
      hash = "sha256-VEnl3q72SZ8ut3jMs+7KyrhXx9Atxu8985UQeo0wMlk=";
    };
    npmDepsHash = "sha256-j1jZUHyRvGNmqF+dU7DoI9ghGbHXWJ8mRxTNWhSAK40=";
    NODE_OPTIONS = "--openssl-legacy-provider";

    installPhase = ''
      mkdir -p $out
      mv build/* $out/
    '';
  };

  new-meta = with lib; {
    description = description;
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta netmaker-ui
