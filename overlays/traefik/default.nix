{ nixpkgs, ... }:
final: prev: {
  traefik = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall = oldAttrs.postInstall or ''
      mkdir -p $out/bin/plugins-local/src/github.com/Amadeus331/
      cp -r ${
        prev.fetchFromGitHub {
          owner = "BilikoX";
          repo = "cloudflarewarp";
          rev = "94ed32a45dcd5656e9b5539e8cd564bd3d7babaa";
          sha256 = "sha256-AU/AgeYLi1e5CaIcXaDoDRWSRyfKHZYfIsp4lPOqnTI=";
        }
      } $out/bin/plugins-local/src/github.com/Amadeus331/cloudflarewarp
    '';
  });
}
