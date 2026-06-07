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
        windowrulev2 = float,class:^(Rofi)$
        windowrulev2 = float,class:^(viewnior)$
        windowrulev2 = float,class:^(feh)$
        windowrulev2 = float,class:^(wlogout)$
        windowrulev2 = float,class:^(file_progress)$
        windowrulev2 = float,class:^(confirm)$
        windowrulev2 = float,class:^(dialog)$
        windowrulev2 = float,class:^(download)$
        windowrulev2 = float,class:^(notification)$
        windowrulev2 = float,class:^(error)$
        windowrulev2 = float,class:^(splash)$
        windowrulev2 = float,class:^(confirmreset)$
        windowrulev2 = float,class:^(polkit-gnome-authentication-agent-1)$
        windowrulev2 = float,class:^(wdisplays)$
        windowrulev2 = size 1100 600,class:^(wdisplays)$
        windowrulev2 = float,class:^(blueman-manager)$
        windowrulev2 = float,class:^(nm-connection-editor)$

        # floating terminal
        windowrulev2 = float,title:^(floating_kitty)$
        windowrulev2 = size 1100 600,title:^(floating_kitty)$
        windowrulev2 = center,title:^(floating_kitty)$
        windowrulev2 = animation slide,title:^(floating_kitty)$

        # calendar reminders
        windowrulev2 = float,class:^(thunderbird)$,title:.*(Reminders)$
        windowrulev2 = size 1100 600,class:^(thunderbird)$,title:.*(Reminders)$
        windowrulev2 = move 78% 6%,class:^(thunderbird)$,title:.*(Reminders)$
        windowrulev2 = pin,class:^(thunderbird)$,title:.*(Reminders)$

        # thunar file operation progress
        windowrulev2 = float,class:^(thunar)$,title:^(File Operation Progress)$
        windowrulev2 = size 800 600,class:^(thunar)$,title:^(File Operation Progress)$
        windowrulev2 = move 78% 6%,class:^(thunar)$,title:^(File Operation Progress)$
        windowrulev2 = pin,class:^(thunar)$,title:^(File Operation Progress)$

        # Workspace 8 (VM) layout
        windowrulev2 = size 1000 1330,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrulev2 = float,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrulev2 = move 80% 6%,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrulev2 = float,class:^(looking-glass-client)$
        windowrulev2 = size 2360 1330,class:^(looking-glass-client)$
        windowrulev2 = move 25% 6%,class:^(looking-glass-client)$
        windowrulev2 = float,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrulev2 = size 2360 1330,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrulev2 = move 25% 6%,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrulev2 = float,class:^(qemu)$
        windowrulev2 = size 2360 1330,class:^(qemu)$
        windowrulev2 = move 25% 6%,class:^(qemu)$

        # make Firefox PiP window floating and sticky
        windowrulev2 = float,title:^(Picture-in-Picture)$
        windowrulev2 = pin,title:^(Picture-in-Picture)$

        # fix xwayland apps
        windowrulev2 = rounding 0,xwayland:1,floating:1
        windowrulev2 = center,class:^(.*jetbrains.*)$,title:^(Confirm Exit|Open Project|win424|win201|splash)$
        windowrulev2 = size 640 400,class:^(.*jetbrains.*)$,title:^(splash)$

        ##
        # ░█▀█░█▀█░█▀█░█▀▀░▀█▀░▀█▀░█░█
        # ░█░█░█▀▀░█▀█░█░░░░█░░░█░░░█░
        # ░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░▀░░░▀░
        ##
        windowrulev2 = opaque,class:^(virt-manager)$,title:.*(on QEMU).*
        windowrulev2 = opaque,class:^(looking-glass-client)$
        windowrulev2 = opaque,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrulev2 = dimaround,class:^(gcr-prompter)$

        # Require input
        windowrulev2 = bordercolor rgba(ed8796FF),class:^(polkit-gnome-authentication-agent-1)$
        windowrulev2 = dimaround,class:^(polkit-gnome-authentication-agent-1)$
        windowrulev2 = stayfocused,class:^(polkit-gnome-authentication-agent-1)$
        windowrulev2 = stayfocused,class:^(Rofi)$
        windowrulev2 = nofocus,class:^(steam)$,title:^()$

        ##
        # ░▀█▀░█▀▄░█░░░█▀▀░▀█▀░█▀█░█░█░▀█▀░█▀▄░▀█▀░▀█▀
        # ░░█░░█░█░█░░░█▀▀░░█░░█░█░█▀█░░█░░█▀▄░░█░░░█░
        # ░▀▀▀░▀▀░░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀▀░░▀▀▀░░▀░
        ##
        windowrulev2 = idleinhibit focus,class:^(steam_app).*
        windowrulev2 = idleinhibit focus,class:^(gamescope).*
        windowrulev2 = idleinhibit focus,class:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrulev2 = idleinhibit fullscreen,title:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrulev2 = idleinhibit fullscreen,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrulev2 = idleinhibit focus,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrulev2 = idleinhibit focus,class:^(mpv|.+exe)$

        ##
        # ░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░░░█▀▀░█▀█░█▀█░█▀▀░▀█▀░█▀▀
        # ░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░░░█░░░█░█░█░█░█▀▀░░█░░█░█
        # ░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░▀░▀░▀░░░▀▀▀░▀▀▀
        ##

        # Secondary Monitor Media
        windowrulev2 = workspace 1,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        #Browsers
        # windowrulev2 = workspace 2,title:^(?!.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        # windowrulev2 = workspace special:inactive,title:^(.*(hidden tabs - Workona)).*(Firefox).*$
        # Code
        windowrulev2 = workspace 3,class:^(Code)$
        windowrulev2 = workspace 3,class:^(neovide)$
        windowrulev2 = workspace 3,class:^(GitHub Desktop)$
        windowrulev2 = workspace 3,class:^(GitKraken)$
        windowrulev2 = workspace 3,class:^(kitty)$,title:^(nvim).*
        # Gaming
        windowrulev2 = workspace 4,class:^(Steam|steam)$
        windowrulev2 = workspace 4,class:^(Steam|steam).,title:^(Steam|steam)$
        windowrulev2 = workspace 4,class:^(gamescope|steam_app).*
        windowrulev2 = workspace 4,class:^(heroic)$
        windowrulev2 = workspace 4,class:^(lutris)$
        windowrulev2 = workspace 4,class:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrulev2 = workspace 4,title:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        # Mail
        windowrulev2 = workspace 5,class:^(thunderbird)$
        windowrulev2 = workspace 5,class:^(Mailspring)$
        # Messaging
        windowrulev2 = workspace 6,title:^(Slack)$
        windowrulev2 = workspace 6,title:^(Mattermost)$
        windowrulev2 = workspace 6,class:^(Caprine)$
        windowrulev2 = workspace 6,class:^(org.telegram.desktop)$
        windowrulev2 = workspace 6,class:^(discord)$
        windowrulev2 = workspace 6,class:^(zoom)$
        windowrulev2 = workspace 6,class:^(Element)$
        # Media
        windowrulev2 = workspace 7,class:^(mpv|vlc|mpdevil)$
        windowrulev2 = workspace 7,class:^(Spotify)$
        windowrulev2 = workspace 7,title:^(Spotify)$
        windowrulev2 = workspace 7,title:^(Spotify Free)$
        windowrulev2 = tile,class:^(Spotify)$
        windowrulev2 = tile,class:^(Spotify Free)$
        windowrulev2 = workspace 7,class:^(elisa)$
        #Remote
        windowrulev2 = workspace 8,class:^(virt-manager|qemu)$
        windowrulev2 = workspace 8,class:^(gnome-connections)$
        windowrulev2 = workspace 8,class:^(looking-glass-client)$
      '';
    };
  };
}
