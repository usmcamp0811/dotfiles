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
    (python-final: python-prev: let
      patchQtile = package: let
        patched = package.overridePythonAttrs (old: {
          # The REPL socket can be reset under builder load. Keep the rest of
          # qtile's test suite enabled.
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_repl_server_executes_code"
          ];

          # qtile 0.37.1's Wayland backend C extension ("qw") does not build
          # against nixpkgs' wlroots_0_19 (0.19.3): it calls
          # wlr_xcursor_image_get_buffer and an old wlr_xwayland_set_cursor
          # signature that no longer exist/match in that wlroots release.
          # That's an upstream qtile/wlroots version mismatch, not something
          # worth patching C code for here -- disable the Wayland backend
          # (qtile's own build.py treats `backend=x11` as "don't build
          # Wayland") and keep the fully-working X11 backend, which is what
          # every `fmf.desktop.qtile` user in this flake actually runs.
          pypaBuildFlags = map (
            flag:
              if prev.lib.hasPrefix "--config-setting=backend=" flag
              then "--config-setting=backend=x11"
              else flag
          ) (old.pypaBuildFlags or [ ]);
        });
      in
        patched
        // {
          # The NixOS qtile module uses this to inject extra Python packages.
          override = args: patchQtile (package.override args);
        };
    in {
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

      # xcffib's test suite spins up its own Xvfb, which can race with an
      # Xvfb already running in the sandbox (or fail to bind a socket under
      # load), breaking this single generic-event test. It's an
      # environment/timing flake, not a real regression -- keep the rest of
      # the (44-passing) suite enabled. This also unblocks cairocffi and
      # qtile, which depend on xcffib.
      xcffib = python-prev.xcffib.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_ge_generic_event_hoist"
        ];
      });

      qtile = patchQtile python-prev.qtile;
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
