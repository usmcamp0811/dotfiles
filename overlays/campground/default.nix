{ campground-nvim, old-nixpkgs, channels, ... }:
final: prev:
{
  campground-nvim = campground-nvim.packages.${prev.system}.nvim;

  neovide = old-nixpkgs.legacyPackages.${prev.system}.neovide;

  matomo_5 = prev.matomo_5.overrideAttrs (old: rec {
    # Fetch the plugin using fetchFromGitHub
    loginOIDCPlugin = prev.fetchFromGitHub {
      owner = "dominik-th";
      repo = "matomo-plugin-LoginOIDC";
      rev = "5.0.0";
      sha256 = "sha256-L1ET2EoO6lm648Xf6UcpT1NR5DU4yBhlzaQyrECFjzQ=";
    };

    # Add the plugin to the installPhase
    installPhase = old.installPhase + ''
      echo "Including LoginOIDC plugin in Matomo package..."
      cp -r ${loginOIDCPlugin} $out/share/plugins/LoginOIDC
    '';
  });
} // {
  inherit (channels.unstable) lemmy-server lemmy-help pds pdsadmin;
}
