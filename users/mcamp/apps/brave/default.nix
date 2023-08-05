{ config, pkgs, lib, ... }:

{
  options.programs.brave.enable = lib.mkEnableOption "Brave browser";

  config = lib.mkIf config.programs.brave.enable {
    programs.brave = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
        { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
        { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
        { id = "iaddfgegjgjelgkanamleadckkpnjpjc"; } # Auto Quality for YouTube
        { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
        { id = "annfbnbieaamhaimclajlajpijgkdblo"; } # Dark Theme
      ];
    };
  };
}

