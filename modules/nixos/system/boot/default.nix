{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.boot;

  # The option only exists in nixpkgs new enough to have boot counting; do not break a consumer
  # that evaluates this module against an older one.
  hasBootCounting = options.boot.loader.systemd-boot ? bootCounting;
in
{
  options.fmf.system.boot = with types; {
    enable = mkBoolOpt false "Whether or not to enable booting.";

    boot-counting = {
      enable =
        mkBoolOpt true
          "Automatic boot assessment (systemd-boot boot counting): a new generation that does not reach boot-complete.target within `tries` boots is skipped and the machine falls back to an older generation. Only takes effect where systemd-boot is enabled, so MicroVMs and other hosts without it are untouched.";
      tries =
        mkOpt types.ints.positive 3
          "Boot attempts a freshly written generation gets before it is considered bad.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.systemd-boot.configurationLimit = 5;
      boot.loader.efi.canTouchEfiVariables = true;

      # https://github.com/NixOS/nixpkgs/blob/c32c39d6f3b1fe6514598fa40ad2cf9ce22c3fb7/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix#L66
      boot.loader.systemd-boot.editor = false;
    }

    # Note: with counting on, the builder stops writing `default <entry>` to loader.conf and writes
    # `preferred <entry-id>` + `default nixos-*`, and entry files carry a counter
    # (nixos-<hash>+3.conf). Anything that parses loader.conf or the entry names must allow for that.
    (optionalAttrs hasBootCounting {
      boot.loader.systemd-boot.bootCounting = mkIf (cfg.boot-counting.enable && config.boot.loader.systemd-boot.enable) {
        enable = true;
        tries = cfg.boot-counting.tries;
      };
    })
  ]);
}
