{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.user;
  defaultIconFileName = "profile.png";
  defaultIcon = pkgs.stdenvNoCC.mkDerivation {
    name = "default-icon";
    src = ./. + "/${defaultIconFileName}";

    dontUnpack = true;

    installPhase = ''
      ${pkgs.coreutils}/bin/cp $src $out
    '';

    passthru = {fileName = defaultIconFileName;};
  };
  propagatedIcon =
    pkgs.runCommand "propagated-icon"
    {
      passthru = {fileName = cfg.icon.fileName;};
    } ''
      local target="$out/share/icons/user/${cfg.name}"
      mkdir -p "$target"

      cp ${cfg.icon} "$target/${cfg.icon.fileName}"
    '';
in {
  options.campground.user = with types; {
    name = mkOpt str "abe" "The name to use for the user account.";
    fullName = mkOpt str "Matt Camp" "The full name of the user.";
    email = mkOpt str "matt@aicampground.com" "The email of the user.";
    uid = mkOpt int 1000 "UID of the user";
    initialPassword =
      mkOpt (nullOr str) "password"
      "The initial password to use when the user is first created.";
    hashedPasswordFile =
      mkOpt (nullOr str) null
      "Path to a file containing the hashed password for the user.";
    icon =
      mkOpt (nullOr package) defaultIcon
      "The profile picture to use for the user.";
    extraGroups = mkOpt (listOf str) [] "Groups for the user to be assigned.";
    extraOptions =
      mkOpt attrs {}
      "Extra options passed to <option>users.users.<name></option>.";
    GroupsIds = mkOption {
      type = types.attrsOf types.int;
      default = {
        users = 10000;
        k8s = 999;
        paperless = 317;
      };
      example = {
        wheel = 10;
        audio = 29;
      };
      description = "Groups and their corresponding IDs.";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [propagatedIcon lsd];

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
        plugins = ["fzf"]; # Oh My Zsh plugins
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
        "Pictures/${
          cfg.icon.fileName or (builtins.baseNameOf cfg.icon)
        }".source =
          cfg.icon;
      };

      configFile = {"sddm/faces/.${cfg.name}".source = cfg.icon;};

      extraOptions = {
        home.shellAliases = {
          la = "${pkgs.lsd}/bin/lsd -lah --group-dirs first";
        };

        programs.zsh.enable = true;

        programs.zsh.history = {
          size = 10000;
          path = "$XDG_CACHE_HOME/zsh/history";
        };
      };
    };

    users.groups =
      mapAttrs' (name: id: nameValuePair name {gid = mkForce id;})
      cfg.GroupsIds;

    users.users.root = cfg.extraOptions;

    users.users.${cfg.name} =
      {
        isNormalUser = true;

        inherit (cfg) name;

        home = "/home/${cfg.name}";
        group = "users";

        shell = pkgs.zsh;

        # Arbitrary user ID to use for the user. Since I only
        # have a single user on my machines this won't ever collide.
        # However, if you add multiple users you'll need to change this
        # so each user has their own unique uid (or leave it out for the
        # system to select).
        uid = cfg.uid;

        extraGroups = [] ++ cfg.extraGroups ++ lib.attrNames cfg.GroupsIds;
      }
      // (optionalAttrs (cfg.initialPassword != null) {
        inherit (cfg) initialPassword;
      })
      // (optionalAttrs (cfg.hashedPasswordFile != null) {
        inherit (cfg) hashedPasswordFile;
      })
      // cfg.extraOptions;
  };
}
