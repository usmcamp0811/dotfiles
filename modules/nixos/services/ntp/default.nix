{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.ntp;
in {
  options.campground.services.ntp = with types; {
    enable = mkBoolOpt false "Enable CAC Support;";
  };

  config = mkIf cfg.enable {
    # networking.timeServers = options.networking.timeServers.default ++ [ "0.arch.pool.ntp.org" ];
    services.ntp.enable = true;
  };
}
