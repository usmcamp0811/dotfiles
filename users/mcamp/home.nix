{ config, pkgs, ... }:

{
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    k9s
    btop
    julia
    deno
    autorandr
    arandr
    feh
  ];

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "https://searx.aicampground.com";
          "browser.search.defaultenginename" = "Searx";
          "browser.search.order.1" = "Searx";
        };
        search = {
          engines = {
            "Searx" = {
              "template" = "https://searx.aicampground.com/?q={searchTerms}";
            };
          };
        };
        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          bitwarden
          darkreader
          vimium
        ];
      };
    };
  };

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

  home.file = { };

  home.sessionVariables = { };

  programs.home-manager.enable = true;
}

