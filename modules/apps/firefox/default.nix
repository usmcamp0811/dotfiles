{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.firefox;
  defaultSettings = {
    "browser.aboutwelcome.enabled" = false;
    "browser.meta_refresh_when_inactive.disabled" = true;
    "browser.startup.homepage" =
      "https://start.duckduckgo.com/?kak=-1&kal=-1&kao=-1&kaq=-1&kt=Hack+Nerd+Font&kae=d&ks=m&k7=2e3440&kj=3b4252&k9=eceff4&kaa=d8dee9&ku=1&k8=d8dee9&kx=81a1c1&k21=3b4252&k18=1&k5=2&kp=-2&k1=-1&kaj=u&kay=b&kk=-1&kax=-1&kap=-1&kau=-1";
    "browser.bookmarks.showMobileBookmarks" = true;
    "browser.urlbar.suggest.quicksuggest.sponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.aboutConfig.showWarning" = false;
    "browser.ssb.enabled" = true;
  };
  cacCertificates = pkgs.fetchurl {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_WCF.zip";
    sha256 = "0myfy951v9mq0f3cf7zmw8mymkcszsmsxdlmiq1j0wk12w6l4qr0";
  };
  cacCertificatesUnzipped = pkgs.runCommandNoCC "cac-certificates" {} ''
    mkdir $out
    unzip ${cacCertificates} -d $out
  '';

  cacCertificatesPaths = builtins.trace (builtins.attrNames (builtins.readDir cacCertificatesUnzipped)) (builtins.map (name: "${cacCertificatesUnzipped}/${name}") (builtins.filter (name: lib.hasSuffix ".p7b" name) (builtins.attrNames (builtins.readDir cacCertificatesUnzipped))));
  firefoxPolicies = pkgs.writeText "policies.json" (builtins.toJSON {
    policies = {
      Certificates = {
        Install = cacCertificatesPaths;
      };
    };
  });
in
{
  options.campground.apps.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
    extraConfig =
      mkOpt str "" "Extra configuration for the user profile JS file.";
    userChrome =
      mkOpt str "" "Extra configuration for the user chrome CSS file.";
    settings = mkOpt attrs defaultSettings "Settings to apply to the profile.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (firefox.overrideAttrs (oldAttrs: {
        postInstall = oldAttrs.postInstall or "" + ''
          mkdir -p $out/lib/firefox/distribution
          cp ${firefoxPolicies} $out/lib/firefox/distribution/policies.json
        '';
      }))
    ];

    # campground.desktop.addons.firefox-nordic-theme = enabled;

    # services.gnome.gnome-browser-connector.enable = config.campground.desktop.qtile.enable;

    campground.home = {
      file = {
        ".mozilla/native-messaging-hosts/com.dannyvankooten.browserpass.json".source = "${pkgs.browserpass}/lib/mozilla/native-messaging-hosts/com.dannyvankooten.browserpass.json";

        # ".mozilla/native-messaging-hosts/org.gnome.chrome_gnome_shell.json".source = mkIf config.campground.desktop.gnome.enable "${pkgs.chrome-gnome-shell}/lib/mozilla/native-messaging-hosts/org.gnome.chrome_gnome_shell.json";
      # };

      extraOptions = {
        programs.firefox = {
          enable = true;
          # package = pkgs.firefox.override (
          #   {
          #     cfg = {
          #       enableBrowserpass = true;
          #       enableGnomeExtensions = config.campground.desktop.gnome.enable;
          #     };
          #
          #     extraNativeMessagingHosts =
          #       optional
          #         config.campground.desktop.gnome.enable
          #         pkgs.gnomeExtensions.gsconnect;
          #   }
          # );

          profiles.${config.campground.user.name} = {
            inherit (cfg) extraConfig userChrome settings;
            id = 0;
            name = config.campground.user.name;
          };
        };
      };
    };

    # TODO: Add things to exploade cac certs and install them into firefox here
    # TODO: See if we can automatically enable services.cac if we say cac enable here
    campground.services.cac.enable = mkIf cfg.cac true;
  };

}

