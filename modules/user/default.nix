{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.user;
  defaultIconFileName = "profile.png";
  defaultIcon = pkgs.stdenvNoCC.mkDerivation {
    name = "default-icon";
    src = ./. + "/${defaultIconFileName}";

    dontUnpack = true;

    installPhase = ''
      cp $src $out
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
    name = mkOpt str "mcamp" "The name to use for the user account.";
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
      histFile = "$XDG_CACHE_HOME/zsh.history";

      interactiveShellInit = ""; # Extra commands to run at interactive shell initialization

      loginShellInit = ""; # Extra commands to run at login shell initialization

      promptInit = ""; # Extra commands to run at prompt initialization

      ohMyZsh = {
        enable = false; # Enable Oh My Zsh
        plugins = [ ]; # Oh My Zsh plugins
        theme = "fino"; # Oh My Zsh theme
        custom = ""; # Custom Oh My Zsh configuration
      };

      initExtra = ''
        for file in ${config.home.homeDirectory}/.config/shell/zsh/*.zsh; do
            [ -r "$file" ] && source "$file"
        done

        # source all the other bash config files
        for file in ${config.home.homeDirectory}/.config/shell/*.shrc; do
            [ -r "$file" ] && source "$file"
        done

        for file in ${config.home.homeDirectory}/.config/shell/private/*.shrc; do
            [ -r "$file" ] && source "$file"
        done

        source ${config.home.homeDirectory}/.config/shell/zsh/theme

      '';
     };

    users.users.${cfg.name} = {
      isNormalUser = true;

      inherit (cfg) name initialPassword;

      home = "/home/${cfg.name}";
      group = "users";

      shell = pkgs.zsh;

      uid = 10000;

      extraGroups = [ "wheel" ] ++ cfg.extraGroups;
    } // cfg.extraOptions;

    system.activationScripts.copyDotfiles = lib.stringAfter
      [ "users" ]
      ''
        echo "Copying dotfiles to ${cfg.name}'s home directory..."
        ${pkgs.bash}/bin/bash -c '
          echo "Dotfiles directory: ${builtins.toString dotfilesDir}"
          for file in ${builtins.toString dotfilesDir}/*; do
            dest="/home/${builtins.toString cfg.name}/.config/$(basename $file)"
            echo "Checking $file..."
            echo "Copying $file to $dest..."
            cp -r $file $dest
            chown -R ${builtins.toString cfg.name}:users $dest
          done
        '
      '';
  };
}

