{ config, pkgs, lib, ... }:

{
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
}

