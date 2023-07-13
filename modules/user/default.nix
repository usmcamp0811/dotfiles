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

    # programs.zsh = {
    #   enable = true;
    #   autosuggestions.enable = true;
    #   histFile = "$XDG_CACHE_HOME/zsh.history";
    # };
    programs.zsh = {
      enable = true; # Enable zsh as the default shell
      enableCompletion = true; # Enable command completion
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      histFile = "$XDG_CACHE_HOME/zsh.history";


      interactiveShellInit = ""; # Extra commands to run at interactive shell initialization

      loginShellInit = ""; # Extra commands to run at login shell initialization

      promptInit = ""; # Extra commands to run at prompt initialization

      # TODO: migrate my theme here
      ohMyZsh = {
        enable = false; # Enable Oh My Zsh
        plugins = [ ]; # Oh My Zsh plugins
        theme = "fino"; # Oh My Zsh theme
        custom = ""; # Custom Oh My Zsh configuration
      };
     };

    campground.home = {
        file = let
          baseFile = {
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
          dotFile = builtins.listToAttrs (map (file: {
            name = ".config/${file}";
            value = {
              source = "${dotfilesDir}/${file}";
            };
          }) dotfiles);
        in baseFile // dotFile;


      extraOptions = {
        home.shellAliases = {
          lc = "${pkgs.colorls}/bin/colorls --sd";
          lcg = "lc --gs";
          lcl = "lc -1";
          lclg = "lc -1 --gs";
          lcu = "${pkgs.colorls}/bin/colorls -U";
          lclu = "${pkgs.colorls}/bin/colorls -U -1";
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

          # for file in /home/${cfg.name}/.config/shell/private/*.shrc; do
          #     [ -r "$file" ] && source "$file"
          # done

          source /home/${cfg.name}/.config/shell/zsh/theme

        '';
      };
    };

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
      # uid = 1000;

      extraGroups = [ "wheel" ] ++ cfg.extraGroups;
    } // cfg.extraOptions;

    users.ldap = {
      enable = true;  # Enable LDAP for user information
      server = "ldap://10.8.0.140:389";
      base = "dc=aicampground,dc=com";  # The base DN of your directory
      bind = {
        distinguishedName = "cn=ldaplookup,ou=ServiceAccounts,dc=aicampground,dc=com";  # The DN to bind to the server
        passwordFile = "/etc/nixos/ldap_bind_password";  # File containing the bind password
        policy = "soft";  # Use simple bind policy
        timeLimit = 5;  # Time limit for bind operations
      };
      daemon = {
        enable = false;  # Not running an LDAP server on this machine
      };
      loginPam = false;  # PAM service name for LDAP logins
      nsswitch = true;  # Enable LDAP for NSS (Name Service Switch)
      useTLS = false;  # Use TLS for the connection, adjust to true if your LDAP server supports TLS
      timeLimit = 5;  # Time limit for LDAP operations
    };

  };
}
