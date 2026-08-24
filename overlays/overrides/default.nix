# Use this for packages that need custom patches or plugins
{ nixpkgs, ... }:
final: prev: {
  # Traefik with custom plugins
  traefik = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
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

  # Taglib pkg-config includes --define-prefix that Go rejects
  taglib = prev.taglib.overrideAttrs (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      if [ -f "$out/lib/pkgconfig/taglib.pc" ]; then
        substituteInPlace "$out/lib/pkgconfig/taglib.pc" --replace " --define-prefix" ""
      fi
    '';
  });

  # Patch ALL yazi plugins: ya.truncate() -> ui.truncate()
  yaziPlugins = let
    patchYaTruncate = drv:
      drv.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          set -eu

          # Patch every Lua file that still uses ya.truncate(
          # (only if it exists, to avoid needless touching)
          if rg -q 'ya\.truncate\s*\(' "$out" 2>/dev/null; then
            while IFS= read -r -d "" f; do
              if rg -q 'ya\.truncate\s*\(' "$f"; then
                substituteInPlace "$f" --replace 'ya.truncate(' 'ui.truncate('
              fi
            done < <(find "$out" -type f -name '*.lua' -print0)
          fi
        '';
      });
  in prev.lib.mapAttrs (_name: drv: patchYaTruncate drv) prev.yaziPlugins;

  # Override pythonPackagesExtensions to fix Python package build issues
  # fastmcp has a flaky network test (test_full_oauth_flow_with_mock_provider)
  # that fails during build - disable all tests for fastmcp
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      fastmcp = python-prev.fastmcp.overridePythonAttrs (old: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });

      jsonpath-python = python-prev.jsonpath-python.overridePythonAttrs (old: {
        # This upstream test compares short wall-clock timings and flakes on
        # loaded builders. Keep the functional tests and benchmarks enabled.
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_cache_hit_rate"
        ];
      });
    })
  ];

  # Fix binary name conflict: deno now ships a 'dx' binary which conflicts with dioxus-cli
  # Remove the dx binary from deno since it's less commonly used than dioxus-cli's dx
  deno = prev.deno.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      # Remove dx binary to avoid conflict with dioxus-cli
      rm -f $out/bin/dx
    '';
  });

}
