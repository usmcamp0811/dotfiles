{ lib
, config
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.tang;
in
{
  options.fmf.services.tang = with types; {
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
