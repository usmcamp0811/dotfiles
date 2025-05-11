{ pkgs
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  devShell = pkgs.mkShell {
    buildInputs = with pkgs; [
      pnpm
      nodejs
      campground.slidev
    ];
  };
in
devShell
