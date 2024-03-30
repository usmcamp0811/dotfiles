{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.tang;
in {
  options.campground.services.tang = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    port = mkOption {
      type = types.listOf types.str;
      default = [ "1234" ];
      description = "Port to Host the tang server on.";
    };
    ipAddressAllow = mkOption {
      type = types.listOf types.str;
      default = [ "10.8.0.1/24" ];
      description = "IP Address to allow";
    };
  };

  config = mkIf cfg.enable {
    services.tang = {
      enable = true;
      listenStream = cfg.port;
      ipAddressAllow = cfg.ipAddressAllow;
    };
  };
}
