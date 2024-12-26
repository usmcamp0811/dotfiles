{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.wg-quick;
in {
  options.campground.services.wg-quick = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    interfaces = mkOption {
      description = ''
        WireGuard interfaces.

        Please note that {option}`systemd.network.netdevs` has more features
        and is better maintained. When building new things, it is advised to
        use that instead.
      '';
      default = {
        campnet = {
          ips = [ "10.8.0.10/24" ];
          privateKeyFile = "/var/lib/wireguard/campnet/private-key";
          peers = [ ];
        };
      };
      example = {
        wg0 = {
          ips = [ "192.168.20.4/24" ];
          privateKeyFile = "/var/lib/wireguard/wg0/private-key";
          peers = [{
            allowedIPs = [ "192.168.20.1/32" ];
            publicKey = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
            endpoint = "demo.wireguard.io:12913";
          }];
        };
      };
      type = with types; attrsOf (submodule interfaceOpts);
    };
  };

  config = mkIf cfg.enable { networking.wg-quick.interfaces = cfg.interfaces; };
}
