{ nixpkgs, ... }:
final: prev: {
  traefik = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall = oldAttrs.postInstall or ''
      mkdir -p $out/bin/plugins-local/src/github.com/BilikoX/
      cp -r ${
        prev.fetchFromGitHub {
          owner = "BilikoX";
          repo = "cloudflarewarp";
          rev = "94ed32a45dcd5656e9b5539e8cd564bd3d7babaa";
          sha256 = "sha256-AU/AgeYLi1e5CaIcXaDoDRWSRyfKHZYfIsp4lPOqnTI=";
        }
      } $out/bin/plugins-local/src/github.com/BilikoX/cloudflarewarp

      mkdir -p $out/bin/plugins-local/src/github.com/tomMoulard/
      cp -r ${
        prev.fetchFromGitHub {
          owner = "tomMoulard";
          repo = "fail2ban";
          rev = "46c5b4c694c0338676d2e22e754620291551e174";
          sha256 = "sha256-vYbhUOS5TWTrBPcp2CESopfXphzK5jky+0oRrMlo9jE=";
        }
      } $out/bin/plugins-local/src/github.com/tomMoulard/fail2ban
    '';
  });
}
