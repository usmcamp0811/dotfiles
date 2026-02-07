{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cache.public;
in {
  options.fmf.cache.public = {
    enable = mkEnableOption "NixOS public cache";
  };
  config = mkIf cfg.enable {
    fmf.nix.extra-substituters = {
      "https://cache.nixos.org/".key = "public:QUkZTErD8fx9HQ64kuuEUZHO9tXNzws7chV8qy/KLUk=";
    };
  };
}
