{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.users;
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
  options.campground.users = with types; mkOption {
    type = listOf (submodule ({ ... }: {
      options = {
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
    }));
    default = [];
  };

  config = {
    environment.systemPackages = with pkgs; [
      propagatedIcon
      lsd
    ];

    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      histFile = "$XDG_CACHE_HOME/zsh.history";
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

    users.users = builtins.listToAttrs (map (user: {
      name = user.name;
      value = {
        isNormalUser = true;
        inherit (user) name initialPassword;
        home = "/home/${user.name}";
        group = "users";
        shell = pkgs.zsh;
        extraGroups = user.extraGroups;
      } // user.extraOptions;
    }) cfg);
  };
}

