{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.fmf.hardware.ckb-next;
in {
  options.fmf.hardware.ckb-next = with types; {
    enable = mkEnableOption "Corsair Keyboards & Mice";
    gid = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 100;
      description = lib.mdDoc ''
        Limit access to the ckb daemon to a particular group.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.ckb-next;
      defaultText = literalExpression "pkgs.ckb-next";
      description = lib.mdDoc ''
        The package implementing the Corsair keyboard/mouse driver.
      '';
    };
  };

  config = mkIf cfg.enable {
    hardware.ckb-next = {
      enable = true;
      gid = cfg.gid;
      package = cfg.package;
    };
  };
}
