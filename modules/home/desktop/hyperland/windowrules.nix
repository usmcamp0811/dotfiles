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
        windowrule = float,class:^(Rofi)$
        windowrule = float,class:^(viewnior)$
        windowrule = float,class:^(feh)$
        windowrule = float,class:^(wlogout)$
        windowrule = float,class:^(file_progress)$
        windowrule = float,class:^(confirm)$
        windowrule = float,class:^(dialog)$
        windowrule = float,class:^(download)$
        windowrule = float,class:^(notification)$
        windowrule = float,class:^(error)$
        windowrule = float,class:^(splash)$
        windowrule = float,class:^(confirmreset)$
        windowrule = float,class:^(polkit-gnome-authentication-agent-1)$
        windowrule = float,class:^(wdisplays)$
        windowrule = size 1100 600,class:^(wdisplays)$
        windowrule = float,class:^(blueman-manager)$
        windowrule = float,class:^(nm-connection-editor)$

        # floating terminal
        windowrule = float,title:^(floating_kitty)$
        windowrule = size 1100 600,title:^(floating_kitty)$
        windowrule = center,title:^(floating_kitty)$
        windowrule = animation slide,title:^(floating_kitty)$

        # calendar reminders
        windowrule = float,class:^(thunderbird)$,title:.*(Reminders)$
        windowrule = size 1100 600,class:^(thunderbird)$,title:.*(Reminders)$
        windowrule = move 78% 6%,class:^(thunderbird)$,title:.*(Reminders)$
        windowrule = pin,class:^(thunderbird)$,title:.*(Reminders)$

        # thunar file operation progress
        windowrule = float,class:^(thunar)$,title:^(File Operation Progress)$
        windowrule = size 800 600,class:^(thunar)$,title:^(File Operation Progress)$
        windowrule = move 78% 6%,class:^(thunar)$,title:^(File Operation Progress)$
        windowrule = pin,class:^(thunar)$,title:^(File Operation Progress)$

        # Workspace 8 (VM) layout
        windowrule = size 1000 1330,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrule = float,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrule = move 80% 6%,class:^(virt-manager)$,title:^(Virtual Machine Manager)$
        windowrule = float,class:^(looking-glass-client)$
        windowrule = size 2360 1330,class:^(looking-glass-client)$
        windowrule = move 25% 6%,class:^(looking-glass-client)$
        windowrule = float,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrule = size 2360 1330,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrule = move 25% 6%,class:^(virt-manager)$,title:^.*(on QEMU/KVM)$
        windowrule = float,class:^(qemu)$
        windowrule = size 2360 1330,class:^(qemu)$
        windowrule = move 25% 6%,class:^(qemu)$

        # make Firefox PiP window floating and sticky
        windowrule = float,title:^(Picture-in-Picture)$
        windowrule = pin,title:^(Picture-in-Picture)$

        # fix xwayland apps
        windowrule = rounding 0,xwayland:1,floating:1
        windowrule = center,class:^(.*jetbrains.*)$,title:^(Confirm Exit|Open Project|win424|win201|splash)$
        windowrule = size 640 400,class:^(.*jetbrains.*)$,title:^(splash)$

        ##
        # ░█▀█░█▀█░█▀█░█▀▀░▀█▀░▀█▀░█░█
        # ░█░█░█▀▀░█▀█░█░░░░█░░░█░░░█░
        # ░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░▀░░░▀░
        ##
        windowrule = opaque,class:^(virt-manager)$,title:.*(on QEMU).*
        windowrule = opaque,class:^(looking-glass-client)$
        windowrule = opaque,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = dimaround,class:^(gcr-prompter)$

        # Require input
        windowrule = bordercolor rgba(ed8796FF),class:^(polkit-gnome-authentication-agent-1)$
        windowrule = dimaround,class:^(polkit-gnome-authentication-agent-1)$
        windowrule = stayfocused,class:^(polkit-gnome-authentication-agent-1)$
        windowrule = stayfocused,class:^(Rofi)$
        windowrule = nofocus,class:^(steam)$,title:^()$

        ##
        # ░▀█▀░█▀▄░█░░░█▀▀░▀█▀░█▀█░█░█░▀█▀░█▀▄░▀█▀░▀█▀
        # ░░█░░█░█░█░░░█▀▀░░█░░█░█░█▀█░░█░░█▀▄░░█░░░█░
        # ░▀▀▀░▀▀░░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀▀░░▀▀▀░░▀░
        ##
        windowrule = idleinhibit focus,class:^(steam_app).*
        windowrule = idleinhibit focus,class:^(gamescope).*
        windowrule = idleinhibit focus,class:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = idleinhibit fullscreen,title:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = idleinhibit fullscreen,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = idleinhibit focus,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        windowrule = idleinhibit focus,class:^(mpv|.+exe)$

        ##
        # ░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░░░█▀▀░█▀█░█▀█░█▀▀░▀█▀░█▀▀
        # ░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░░░█░░░█░█░█░█░█▀▀░░█░░█░█
        # ░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░▀░▀░▀░░░▀▀▀░▀▀▀
        ##

        # Secondary Monitor Media
        windowrule = workspace 1,title:^(.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        #Browsers
        # windowrule = workspace 2,title:^(?!.*(Twitch|TNTdrama|YouTube|Bally Sports|Video Entertainment|Plex)).*(Firefox).*$
        # windowrule = workspace special:inactive,title:^(.*(hidden tabs - Workona)).*(Firefox).*$
        # Code
        windowrule = workspace 3,class:^(Code)$
        windowrule = workspace 3,class:^(neovide)$
        windowrule = workspace 3,class:^(GitHub Desktop)$
        windowrule = workspace 3,class:^(GitKraken)$
        windowrule = workspace 3,class:^(kitty)$,title:^(nvim).*
        # Gaming
        windowrule = workspace 4,class:^(Steam|steam)$
        windowrule = workspace 4,class:^(Steam|steam).,title:^(Steam|steam)$
        windowrule = workspace 4,class:^(gamescope|steam_app).*
        windowrule = workspace 4,class:^(heroic)$
        windowrule = workspace 4,class:^(lutris)$
        windowrule = workspace 4,class:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        windowrule = workspace 4,title:.*(cemu|yuzu|ryujinx|emulationstation|retroarch).*
        # Mail
        windowrule = workspace 5,class:^(thunderbird)$
        windowrule = workspace 5,class:^(Mailspring)$
        # Messaging
        windowrule = workspace 6,title:^(Slack)$
        windowrule = workspace 6,title:^(Mattermost)$
        windowrule = workspace 6,class:^(Caprine)$
        windowrule = workspace 6,class:^(org.telegram.desktop)$
        windowrule = workspace 6,class:^(discord)$
        windowrule = workspace 6,class:^(zoom)$
        windowrule = workspace 6,class:^(Element)$
        # Media
        windowrule = workspace 7,class:^(mpv|vlc|mpdevil)$
        windowrule = workspace 7,class:^(Spotify)$
        windowrule = workspace 7,title:^(Spotify)$
        windowrule = workspace 7,title:^(Spotify Free)$
        windowrule = tile,class:^(Spotify)$
        windowrule = tile,class:^(Spotify Free)$
        windowrule = workspace 7,class:^(elisa)$
        #Remote
        windowrule = workspace 8,class:^(virt-manager|qemu)$
        windowrule = workspace 8,class:^(gnome-connections)$
        windowrule = workspace 8,class:^(looking-glass-client)$
      '';
    };
  };
}
