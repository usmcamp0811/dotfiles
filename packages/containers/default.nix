{ lib
, writeText
, writeShellApplication
, substituteAll
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "Hello World Docker Image";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };

  # Builds a native Nix image but intended for an OCI-compliant registry.
  hello-nix = pkgs.nix-snapshotter.buildImage {
    name = "ghcr.io/pdtpartners/hello";
    tag = "latest";
    config.entrypoint = [ "${pkgs.hello}/bin/hello" ];
  };
in 

override-meta new-meta hello-nix
