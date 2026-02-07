{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.suites.gaming;
in {
  options.fmf.suites.gaming = with types; {
    enable = mkBoolOpt false "Whether or not to enable gaming configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      [ pkgs.lutris pkgs.steam pkgs.prismlauncher pkgs.mangohud ];
  };
}
