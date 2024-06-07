{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.public-hosting;
in {
  options.campground.suites.public-hosting = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable observability reporters.";
    loki-uri = mkOpt str "webb:3030" "The <host>:<port> of the Loki server";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        prometheus = { exporter-enable = true; };
        promtail = {
          enable = true;
          loki-uri = cfg.loki-uri;
        };
      };
    };
  };
}
