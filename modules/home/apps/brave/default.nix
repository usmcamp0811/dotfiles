{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.brave;
in
{
  options.fmf.apps.brave = with types; {
    enable = mkBoolOpt false "Whether or not to enable Brave.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
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
        { id = "elifhakcjgalahccnjkneoccemfahfoa"; } # Markdown Here
      ];
    };
    # systemd.services.installCACerts = {
    #   description = "Install CAC certificates into Chromium based Browsers";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = "yes";
    #     ExecStart = "${installCACertsScript}";
    #   };
    # };
  };
  # TODO: Add this shell script to set searx as default search
  # #!/bin/bash
  #
  # # Define the search engine JSON entry with favicon_url
  # search_engine='{
  #   "default": false,
  #   "name": "Searx",
  #   "keyword": "searx",
  #   "search_url": "https://searx.aicampground.com/search?q={searchTerms}",
  #   "suggestions_url": "",
  #   "favicon_url": "https://searx.aicampground.com/static/themes/simple/img/favicon.svg"
  # }'
  #
  # # Escape special characters for sed
  # escaped_search_engine=$(echo "$search_engine" | sed 's/[\/&]/\\&/g')
  #
  # # Path to the Preferences file
  # preferences_file="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
  #
  # # Add the new search engine entry to Preferences
  # sed -i "/\"search_engines\": \[/a $escaped_search_engine," "$preferences_file"
  #
  # echo "New search engine 'Searx' with favicon added to Preferences."
}
