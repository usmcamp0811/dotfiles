{nixpkgs, ...}: final: prev: {
  # Traefik with custom plugins
  traefik = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # Add CloudflareWarp plugin
        mkdir -p $out/bin/plugins-local/src/github.com/BilikoX/
        cp -r ${
          prev.fetchFromGitHub {
            owner = "BilikoX";
            repo = "cloudflarewarp";
            rev = "94ed32a45dcd5656e9b5539e8cd564bd3d7babaa";
            sha256 = "sha256-AU/AgeYLi1e5CaIcXaDoDRWSRyfKHZYfIsp4lPOqnTI=";
          }
        } $out/bin/plugins-local/src/github.com/BilikoX/cloudflarewarp

        # Add fail2ban plugin
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

  # Patch yaziPlugins.yatline: ya.truncate() -> ui.truncate()
  yaziPlugins =
    prev.yaziPlugins
    // {
      yatline = prev.yaziPlugins.yatline.overrideAttrs (oldAttrs: {
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            set -eu

            target="$(find "$out" -type f -name main.lua -path '*/yatline.yazi/*' | head -n1 || true)"
            if [ -z "$target" ]; then
              echo "ERROR: could not find yatline main.lua under $out"
              find "$out" -maxdepth 5 -type f -name 'main.lua' -print
              exit 1
            fi

            substituteInPlace "$target" \
              --replace 'ya.truncate(' 'ui.truncate('
          '';
      });
    };
}
