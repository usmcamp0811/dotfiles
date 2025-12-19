{ options
, config
, lib
, ...
}:
with lib; let
  cfg = config.fmf.hardware.intel;
in
{
  options.fmf.hardware.intel = with types; {
    enable = mkEnableOption "Intel Graphics";
  };

  config = mkIf cfg.enable {
    # services.xserver.videoDrivers = [ "intel" ];
  };
}
