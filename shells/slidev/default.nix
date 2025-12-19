{ pkgs
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  devShell = pkgs.mkShell {
    buildInputs = with pkgs; [
      pnpm
      nodejs
      fmf.slidev
    ];
  };
in
devShell
