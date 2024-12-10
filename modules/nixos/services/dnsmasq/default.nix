{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.dnsmasq;
in {
  options.campground.services.dnsmasq = with types; {
    enable = mkBoolOpt false "Enable dnsmasq.";

    settings = mkOption {
      type = attrsOf (attrsOf str);
      default = {
        listenAddress = "0.0.0.0"; # Default to localhost
        interface = "wg0"; # Optional interface binding
        extraConfig = "";
      };
      description = ''
        Configuration for dnsmasq. Refer to the dnsmasq documentation for details on supported options.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      extraConfig = cfg.settings.extraConfig;

      # Optional interface binding and listen address
      listenAddress = cfg.settings.listenAddress;
      interface = cfg.settings.interface;
    };
  };
}
