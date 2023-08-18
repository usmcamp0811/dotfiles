{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.user;
  defaultIconFileName = "profile.png";
  defaultIcon = pkgs.stdenvNoCC.mkDerivation {
    name = "default-icon";
    src = ./. + "/${defaultIconFileName}";

    dontUnpack = true;

    installPhase = ''
      ${pkgs.coreutils}/bin/cp $src $out
    '';

    passthru = { fileName = defaultIconFileName; };
  };
  propagatedIcon = pkgs.runCommandNoCC "propagated-icon"
    { passthru = { fileName = cfg.icon.fileName; }; }
    ''
      local target="$out/share/campground-icons/user/${cfg.name}"
      mkdir -p "$target"

      cp ${cfg.icon} "$target/${cfg.icon.fileName}"
    '';

  dotfilesDir = ./dotfiles/.config;
  dotfiles = builtins.attrNames (builtins.readDir dotfilesDir);

in
{
  options.campground.user = with types; {
    name = mkOpt str "abe" "The name to use for the user account.";
    fullName = mkOpt str "Matt Camp" "The full name of the user.";
    email = mkOpt str "matt@aicampground.com" "The email of the user.";
    initialPassword = mkOpt str "password"
      "The initial password to use when the user is first created.";
    icon = mkOpt (nullOr package) defaultIcon
      "The profile picture to use for the user.";
    extraGroups = mkOpt (listOf str) [ ] "Groups for the user to be assigned.";
    extraOptions = mkOpt attrs { }
      "Extra options passed to <option>users.users.<name></option>.";
  };

  config = {
    environment.systemPackages = with pkgs; [
      propagatedIcon
      lsd
    ];

    programs.zsh = {
      enable = true; # Enable zsh as the default shell
      enableCompletion = true; # Enable command completion
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      interactiveShellInit = ""; # Extra commands to run at interactive shell initialization

      loginShellInit = ""; # Extra commands to run at login shell initialization

      promptInit = ""; # Extra commands to run at prompt initialization

      # TODO: migrate my theme here
      ohMyZsh = {
        enable = true; # Enable Oh My Zsh
        plugins = [ "fzf" ]; # Oh My Zsh plugins
        # theme = "fino"; # Oh My Zsh theme
        # custom = ""; # Custom Oh My Zsh configuration
      };
     };

    campground.home = {
        file = {
            "Desktop/.keep".text = "";
            "Documents/.keep".text = "";
            "Downloads/.keep".text = "";
            "Music/.keep".text = "";
            "Pictures/.keep".text = "";
            "Videos/.keep".text = "";
            "work/.keep".text = "";
            ".face".source = cfg.icon;
            "Pictures/${cfg.icon.fileName or (builtins.baseNameOf cfg.icon)}".source = cfg.icon;
          };


      extraOptions = {
        home.shellAliases = {
          la = "lsd -lah";
          update = "sudo nixos-rebuild switch";
        };

        programs.zsh.enable = true;

        programs.zsh.initExtra = ''
          for file in /home/${cfg.name}/.config/shell/zsh/*.zsh; do
              [ -r "$file" ] && source "$file"
          done

          # source all the other bash config files
          for file in /home/${cfg.name}/.config/shell/*.shrc; do
              [ -r "$file" ] && source "$file"
          done

          source /home/${cfg.name}/.config/shell/zsh/theme
        '';

        programs.zsh.history = {
          size = 10000;
          path = "$XDG_CACHE_HOME/zsh/history";
        };

      };
    };

    users.users.root = {
      shell = pkgs.zsh;
    } // cfg.extraOptions;

   users.users.${cfg.name} = {
     isNormalUser = true;

     inherit (cfg) name initialPassword;

     home = "/home/${cfg.name}";
     group = "users";

     shell = pkgs.zsh;

     # Arbitrary user ID to use for the user. Since I only
     # have a single user on my machines this won't ever collide.
     # However, if you add multiple users you'll need to change this
     # so each user has their own unique uid (or leave it out for the
     # system to select).
     uid = 1000;

     extraGroups = [ "wheel" ] ++ cfg.extraGroups;
   } // cfg.extraOptions;


    system.activationScripts.copyDotfiles = lib.stringAfter
      [ "users" ]
      ''
        echo "Copying dotfiles to ${cfg.name}'s home directory..."
        ${pkgs.bash}/bin/bash -c '
          echo "Dotfiles directory: ${builtins.toString dotfilesDir}"
          for file in ${builtins.toString dotfilesDir}/*; do
            dest="/home/${builtins.toString cfg.name}/.config/"
            echo "Checking $file..."
            echo "Copying $file to $dest..."
            mkdir -p /home/${builtins.toString cfg.name}/.config
            chown -R ${builtins.toString cfg.name}:users $dest
            chmod -R 755 /home/${builtins.toString cfg.name}/.config
            ${pkgs.rsync}/bin/rsync -a $file $dest
            chown -R ${builtins.toString cfg.name}:ldap_user $dest
          done
        '
      '';
    # TODO: Make what gets copied here more generic for all users
    # TODO: This needs a zshrc or does it? home-manager needs to be accessible
    system.activationScripts.copySkelDotfiles = lib.stringAfter
      [ "users" ]
      ''
        echo "Copying dotfiles to /etc/skel home directory..."
        ${pkgs.bash}/bin/bash -c '
          rm -rf /etc/skel/*
          echo "Dotfiles directory: ${builtins.toString dotfilesDir}"
          for file in ${builtins.toString dotfilesDir}/*; do
            dest="/etc/skel/.config/"
            echo "Checking $file..."
            echo "Copying $file to $dest..."
            mkdir -p /etc/skel/.config/
            ${pkgs.rsync}/bin/rsync -a $file $dest
          done
        '
      '';
  };
}


