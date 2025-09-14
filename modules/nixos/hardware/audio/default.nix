# modules/campground/hardware/audio.nix
{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.hardware.audio;
in {
  options.campground.hardware.audio = with types; {
    enable = mkBoolOpt false "Whether or not to enable audio support.";
    alsa-monitor = mkOpt attrs {} "Alsa configuration.";
    nodes = mkOpt (listOf attrs) [] "Audio nodes to pass to Pipewire as `context.objects`.";
    modules = mkOpt (listOf attrs) [] "Audio modules to pass to Pipewire as `context.modules`.";
    extra-packages = mkOpt (listOf package) [pkgs.qjackctl pkgs.easyeffects] "Additional packages to install.";
  };

  config = mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;

      # PipeWire clock/rate/quantum to prevent HDMI underruns
      extraConfig.pipewire."99-hdmi-tweaks.conf".context.properties = {
        default.clock.rate = 48000;
        default.clock.allowed-rates = [48000];
        default.clock.quantum = 1024;
        default.clock.min-quantum = 1024;
        default.clock.max-quantum = 2048;
      };

      # WirePlumber: no auto-suspend + lower per-app latency for Brave
      wireplumber.extraConfig."51-no-suspend.lua" = ''
        alsa_monitor = alsa_monitor or {}
        alsa_monitor.rules = alsa_monitor.rules or {}

        table.insert(alsa_monitor.rules, {
          matches = { { { "node.name", "matches", "alsa_output.*" } } },
          apply_properties = { ["session.suspend-timeout-seconds"] = 0 }
        })

        table.insert(alsa_monitor.rules, {
          matches = { { { "application.name", "matches", "Brave*" } } },
          apply_properties = {
            ["node.pause-on-idle"] = false,
            ["node.latency"] = "1024/48000"
          }
        })
      '';
    };

    # Disable legacy PulseAudio daemon
    services.pulseaudio.enable = mkForce false;

    # Stop HDA HDMI codec from idling
    boot.kernelParams = [
      "snd_hda_intel.power_save=0"
      "snd_hda_intel.power_save_controller=0"
    ];

    environment.systemPackages = with pkgs; [pulsemixer pavucontrol] ++ cfg.extra-packages;

    campground.user.extraGroups = ["audio"];

    campground.home.extraOptions = {
      systemd.user.services.mpris-proxy = {
        Unit.Description = "Mpris proxy";
        Unit.After = ["network.target" "sound.target"];
        Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
        Install.WantedBy = ["default.target"];
      };
    };
  };
}
