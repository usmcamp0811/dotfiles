{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.hyprland;
in {
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      extraConfig = ''
        # ░█░█░▀█▀░█▀█░█▀▄░█▀█░█░█░░░█▀▄░█░█░█░░░█▀▀░█▀▀
        # ░█▄█░░█░░█░█░█░█░█░█░█▄█░░░█▀▄░█░█░█░░░█▀▀░▀▀█
        # ░▀░▀░▀▀▀░▀░▀░▀▀░░▀▀▀░▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀
        # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

        ##
        # ░█▀▀░█░░░█▀█░█▀█░▀█▀░▀█▀░█▀█░█▀▀
        # ░█▀▀░█░░░█░█░█▀█░░█░░░█░░█░█░█░█
        # ░▀░░░▀▀▀░▀▀▀░▀░▀░░▀░░▀▀▀░▀░▀░▀▀▀
        ##
        windowrule = float 1,match:class ^(Rofi)$
        windowrule = float 1,match:class ^(viewnior)$
        windowrule = float 1,match:class ^(feh)$
        windowrule = float 1,match:class ^(wlogout)$
        windowrule = float 1,match:class ^(file_progress)$
        windowrule = float 1,match:class ^(confirm)$
        windowrule = float 1,match:class ^(dialog)$
        windowrule = float 1,match:class ^(download)$
        windowrule = float 1,match:class ^(notification)$
        windowrule = float 1,match:class ^(error)$
        windowrule = float 1,match:class ^(splash)$
        windowrule = float 1,match:class ^(confirmreset)$
        windowrule = float 1,match:class ^(polkit-gnome-authentication-agent-1)$
        windowrule = float 1,match:class ^(wdisplays)$
        windowrule = size 1100 600,match:class ^(wdisplays)$
        windowrule = float 1,match:class ^(blueman-manager)$
        windowrule = float 1,match:class ^(nm-connection-editor)$

        # floating terminal
        windowrule = float 1,match:title ^(floating_kitty)$
        windowrule = size 1100 600,match:title ^(floating_kitty)$
        windowrule = center 1,match:title ^(floating_kitty)$
        windowrule = animation slide,match:title ^(floating_kitty)$

        # calendar reminders
        windowrule = float 1,match:class ^(thunderbird)$,match:title .*(Reminders)$
        windowrule = size 1100 600,match:class ^(thunderbird)$,match:title .*(Reminders)$
        windowrule = move 78% 6%,match:class ^(thunderbird)$,match:title .*(Reminders)$
        windowrule = pin 1,match:class ^(thunderbird)$,match:title .*(Reminders)$

        # thunar file operation progress
        windowrule = float 1,match:class ^(thunar)$,match:title ^(File Operation Progress)$
        windowrule = size 800 600,match:class ^(thunar)$,match:title ^(File Operation Progress)$
        windowrule = move 78% 6%,match:class ^(thunar)$,match:title ^(File Operation Progress)$
        windowrule = pin 1,match:class ^(thunar)$,match:title ^(File Operation Progress)$

        # Workspace 8 (VM) layout
        windowrule = size 1000 1330,match:class ^(virt-manager)$,match:title ^(Virtual Machine Manager)$
        windowrule = float 1,match:class ^(virt-manager)$,match:title ^(Virtual Machine Manager)$
        windowrule = move 80% 6%,match:class ^(virt-manager)$,match:title ^(Virtual Machine Manager)$
        windowrule = float 1,match:class ^(looking-glass-client)$
        windowrule = size 2360 1330,match:class ^(looking-glass-client)$
        windowrule = move 25% 6%,match:class ^(looking-glass-client)$
        windowrule = float 1,match:class ^(virt-manager)$,match:title ^.*(on QEMU/KVM)$
        windowrule = size 2360 1330,match:class ^(virt-manager)$,match:title ^.*(on QEMU/KVM)$
        windowrule = move 25% 6%,match:class ^(virt-manager)$,match:title ^.*(on QEMU/KVM)$
        windowrule = float 1,match:class ^(qemu)$
        windowrule = size 2360 1330,match:class ^(qemu)$
        windowrule = move 25% 6%,match:class ^(qemu)$

        # make Firefox PiP window floating and sticky
        windowrule = float 1,match:title ^(Picture-in-Picture)$
        windowrule = pin 1,match:title ^(Picture-in-Picture)$

        # fix xwayland apps
        windowrule = rounding 0,match:xwayland 1,match:float 1
        windowrule = center 1,match:class ^(.*jetbrains.*)$,match:title ^(Confirm Exit|Open Project|win424|win201|splash)$
        windowrule = size 640 400,match:class ^(.*jetbrains.*)$,match:title ^(splash)$

        ##
        # ░█▀█░█▀█░█▀█░█▀▀░▀█▀░▀█▀░█░█
        # ░█░█░█▀▀░█▀█░█░░░░█░░░█░░░█░
        # ░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░▀░░░▀░
        ##
        windowrule = opaque 1,match:class ^(virt-manager)$,match:title .*(on QEMU).*
        windowrule = opaque 1,match:class ^(looking-glass-client)$
        windowrule = opaque 1,match:title ^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = dim_around 1,match:class ^(gcr-prompter)$

        # Require input
        windowrule = border_color rgba(ed8796FF),match:class ^(polkit-gnome-authentication-agent-1)$
        windowrule = dim_around 1,match:class ^(polkit-gnome-authentication-agent-1)$
        windowrule = stay_focused 1,match:class ^(polkit-gnome-authentication-agent-1)$
        windowrule = stay_focused 1,match:class ^(Rofi)$
        windowrule = no_focus 1,match:class ^(steam)$,match:title ^()$

        ##
        # ░▀█▀░█▀▄░█░░░█▀▀░▀█▀░█▀█░█░█░▀█▀░█▀▄░▀█▀░▀█▀
        # ░░█░░█░█░█░░░█▀▀░░█░░█░█░█▀█░░█░░█▀▄░░█░░░█░
        # ░▀▀▀░▀▀░░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀▀░░▀▀▀░░▀░
        ##
        windowrule = idle_inhibit focus,match:class ^(steam_app).*
        windowrule = idle_inhibit focus,match:class ^(gamescope).*
        windowrule = idle_inhibit focus,match:class .*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = idle_inhibit fullscreen,match:title .*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = idle_inhibit fullscreen,match:title ^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = idle_inhibit focus,match:title ^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = idle_inhibit focus,match:class ^(mpv|.+exe)$

        ##
        # ░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░░░█▀▀░█▀█░█▀█░█▀▀░▀█▀░█▀▀
        # ░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░░░█░░░█░█░█░█░█▀▀░░█░░█░█
        # ░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░▀░▀░▀░░░▀▀▀░▀▀▀
        ##

        # Secondary Monitor Media
        windowrule = workspace 1,match:title ^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        #Browsers
        # windowrule = workspace 2,title:^(?!.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        # windowrule = workspace special:inactive,title:^(.*(hidden tabs - Workona)).*(Firefox).*$
        # Code
        windowrule = workspace 3,match:class ^(Code)$
        windowrule = workspace 3,match:class ^(neovide)$
        windowrule = workspace 3,match:class ^(GitHub Desktop)$
        windowrule = workspace 3,match:class ^(GitKraken)$
        windowrule = workspace 3,match:class ^(kitty)$,match:title ^(nvim).*
        # Gaming
        windowrule = workspace 4,match:class ^(Steam|steam)$
        windowrule = workspace 4,match:class ^(Steam|steam).,match:title ^(Steam|steam)$
        windowrule = workspace 4,match:class ^(gamescope|steam_app).*
        windowrule = workspace 4,match:class ^(heroic)$
        windowrule = workspace 4,match:class ^(lutris)$
        windowrule = workspace 4,match:class .*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = workspace 4,match:title .*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        # Mail
        windowrule = workspace 5,match:class ^(thunderbird)$
        windowrule = workspace 5,match:class ^(Mailspring)$
        # Messaging
        windowrule = workspace 6,match:title ^(Slack)$
        windowrule = workspace 6,match:title ^(Mattermost)$
        windowrule = workspace 6,match:class ^(Caprine)$
        windowrule = workspace 6,match:class ^(org.telegram.desktop)$
        windowrule = workspace 6,match:class ^(discord)$
        windowrule = workspace 6,match:class ^(zoom)$
        windowrule = workspace 6,match:class ^(Element)$
        # Media
        windowrule = workspace 7,match:class ^(mpv|vlc|mpdevil)$
        windowrule = workspace 7,match:class ^(Spotify)$
        windowrule = workspace 7,match:title ^(Spotify)$
        windowrule = workspace 7,match:title ^(Spotify Free)$
        windowrule = tile 1,match:class ^(Spotify)$
        windowrule = tile 1,match:class ^(Spotify Free)$
        windowrule = workspace 7,match:class ^(elisa)$
        #Remote
        windowrule = workspace 8,match:class ^(virt-manager|qemu)$
        windowrule = workspace 8,match:class ^(gnome-connections)$
        windowrule = workspace 8,match:class ^(looking-glass-client)$
      '';
    };
  };
}
