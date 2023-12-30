{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, specialArgs
, nix 
, hosts ? { }
, ...
}:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  pname = "nixery";
  storagePath = "/var/lib/nixery";

  nixery = specialArgs.nixery-pkgs.nixery.overrideAttrs(old: {
    # Drop the nix-1p documentation page as it doesn't build in pure evaluation.
    postInstall = ''
      wrapProgram $out/bin/server \
        --prefix PATH : ${specialArgs.nixery-pkgs.nixery-prepare-image}/bin \
        --prefix PATH : ${nix}/bin
    '';
  });

  new-meta = with lib; {
    description = "Nixery";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };
in
# {
#   # If k0s should be in the PATH:
#   # environment.systemPackages = [ k0s ];
#
# }
override-meta new-meta nixery


