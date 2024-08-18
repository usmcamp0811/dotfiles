{ lib, config, ... }:
with lib;
with lib.campground;
let

  cfg = config.campground.services.barrier;
in {
  options.campground.services.barrier = {
    enable = mkBoolOpt false "Enable Barrier KVM";
    server = mkOpt types.str "192.168.1.3:24800" "Server address";
  };

  config = mkIf cfg.enable {
    services = {
      barrier = {
        client = {
          enable = true;
          enableCrypto = true;
          enableDragDrop = true;

          inherit (cfg) server;
        };
      };
    };
  };
}
