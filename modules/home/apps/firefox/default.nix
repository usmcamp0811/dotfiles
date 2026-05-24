{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.apps.firefox;
in {
  options.fmf.apps.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    stylix.targets.firefox.profileNames = [ "default" ];

    # environment.systemPackages = with pkgs; [
    #   nssTools
    #   firefox
    # ];

    programs.firefox = {
      enable = true;
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
            force = true;
            default = "Searx";
            order = [ "Searx" "google" ];
            engines = {
              "Nix Packages" = {
                urls = [{
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }];
                icon =
                  "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@np" ];
              };
              "NixOS Wiki" = {
                urls = [{
                  template =
                    "https://nixos.wiki/index.php?search={searchTerms}";
                }];
                icon = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@nw" ];
              };
              "Searx" = {
                urls = [{
                  template = "https://searx.aicampground.com/?q={searchTerms}";
                }];
                icon = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@searx" ];
              };
              "bing".metaData.hidden = true;
              "google".metaData.alias =
                "@g"; # builtin engines only support specifying one additional alias
            };
          };
          extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            bitwarden
            darkreader
            vimium
            simplelogin
          ];
        };
      };
    };
    # # TODO: Add things to exploade cac certs and install them into firefox here
    # fmf.services.cac.enable = mkIf cfg.cac true;
  };
}
# TODO: Read this and do something with it
# https://github.com/NixOS/nixpkgs/issues/171978
# Firefox needs to be convinced to use p11-kit-proxy by running a command like this:
#
# modutil -add p11-kit-proxy -libfile ${p11-kit}/lib/p11-kit-proxy.so -dbdir ~/.mozilla/firefox/*.default
# I was also able to accomplish the same by making use of extraPolciies when overriding the firefox package:
#
#         extraPolicies = {
#           SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
#         };
