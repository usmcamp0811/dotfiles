{ inputs, lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.flakeforge;

in {
  options.campground.services.flakeforge = with types; {
    enable = mkBoolOpt false "Enable Flake Forge";
    listenAddress = mkOption {
      type = str;
      default = "0.0.0.0";
      description = "The address to listen on.";
    };
    port = mkOption {
      type = port;
      default = 15000;
      description = "The port to listen on.";
    };
    flakeRoot = mkOption {
      type = str;
      default = "gitlab:usmcamp0811/dotfiles";
      description = "The flake root to serve images from.";
    };
    extraFlags = mkOption {
      type = listOf types.str;
      default = [ ];
      description = "Extra flags to pass to flakeforge.";
    };
  };

  config = mkIf cfg.enable {
    services.flakeforge = {
      enable = cfg.enable;
      listenAddress = cfg.listenAddress;
      listenPort = cfg.port;
      flakeRoot = cfg.flakeRoot;
      extraFlags = cfg.extraFlags;
    };
  };
}
