{ options
, config
, pkgs
, lib
, ...
}:
# @FIXME(jakehamilton): The transition to wireplumber from media-session has completely
# broken my setup. I'll need to invest some time to figure out how to override Alsa things
# again...
with lib;
with lib.campground; let
  cfg = config.campground.hardware.audio;
in
{
  options.campground.hardware.audio = with types; {
    enable = mkBoolOpt false "Whether or not to enable audio support.";
    alsa-monitor = mkOpt attrs { } "Alsa configuration.";
    nodes =
      mkOpt (listOf attrs) [ ]
        "Audio nodes to pass to Pipewire as `context.objects`.";
    modules =
      mkOpt (listOf attrs) [ ]
        "Audio modules to pass to Pipewire as `context.modules`.";
    extra-packages =
      mkOpt (listOf package) [ pkgs.qjackctl pkgs.easyeffects ]
        "Additional packages to install.";
  };

  config = mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;

      wireplumber.enable = true;
    };

    # environment.etc = {
    #   "pipewire/pipewire.conf.d/10-pipewire.conf".source =
    #     pkgs.writeText "pipewire.conf" (builtins.toJSON pipewire-config);
    #   # "pipewire/pipewire.conf.d/21-alsa.conf".source =
    #   #   pkgs.writeText "pipewire.conf" (builtins.toJSON alsa-config);
    #   #
    #   # "wireplumber/wireplumber.conf".source =
    #   #   pkgs.writeText "pipewire.conf" (builtins.toJSON pipewire-config);
    #   #
    #   # "wireplumber/scripts/config.lua.d/alsa.lua".text = ''
    #   #   local input = ${lua-format.generate "sample.lua" cfg.alsa-monitor}
    #   #
    #   #   if input.rules == nil then
    #   #    input.rules = {}
    #   #   end
    #   #
    #   #   local rules = input.rules
    #   #
    #   #   for _, rule in ipairs(input.rules) do
    #   #     table.insert(alsa_monitor.rules, rule)
    #   #   end
    #   # '';
    # };

    services.pulseaudio.enable = mkForce false;

    environment.systemPackages = with pkgs;
      [ pulsemixer pavucontrol ] ++ cfg.extra-packages;

    campground.user.extraGroups = [ "audio" ];

    campground.home.extraOptions = {
      systemd.user.services.mpris-proxy = {
        Unit.Description = "Mpris proxy";
        Unit.After = [ "network.target" "sound.target" ];
        Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
