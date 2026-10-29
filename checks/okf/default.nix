{
  pkgs,
  inputs,
  ...
}:
# The okf tool's own tests, the repo's OKF bundles, and the website built from them:
# no spec errors, every generated index.md up to date, no broken local links in the
# site, nothing loaded from outside it, and a launcher that opens the right URL.
# Warnings (for example a broken link inside a document) are advice and do not fail
# this check; run `okf check --strict` to see them as failures.
#
#   nix build .#checks.x86_64-linux.okf
let
  okf = pkgs.fmf.okf;
  docs = pkgs.fmf.campground;
  site = "${docs}/share/campground";
  src = inputs.self;
in
  pkgs.runCommand "okf-check" {
    nativeBuildInputs = [okf okf.python-env pkgs.gnugrep pkgs.findutils];
  } ''
    export PYTHONDONTWRITEBYTECODE=1

    cp -r ${src}/packages/scripts/okf tool
    (cd tool && python -m unittest)
    cp -r ${src}/packages/applications/campground options-tool
    (cd options-tool && python -m unittest)

    cd ${src}
    okf check docs modules systems
    okf index docs modules systems

    # The site: built by Campground, which already fails on any broken local link.
    okf site verify ${site}
    test -f ${site}/index.html
    test -f ${site}/search.html
    test -f ${site}/options/index.html
    grep -q 'fmf.services.immich.enable' ${site}/options/fmf/services/immich.html
    grep -q 'Module guide' ${site}/options/fmf/services/immich.html

    # Works offline: no page loads a script, stylesheet or image from elsewhere.
    if grep -rEl --include='*.html' '<(script|link|img)[^>]*(src|href)="(https?:)?//' ${site}; then
      echo "a page loads a remote resource" >&2
      exit 1
    fi

    # The launcher prints, and would open, the right URL; failures are loud.
    test "$(${docs}/bin/campground --print)" = "file://${site}/index.html"
    test "$(OKF_BROWSER=echo ${docs}/bin/campground)" = "file://${site}/index.html"
    test "$(${docs}/bin/campground --browser echo --search 'type:Guide a b')" = "file://${site}/search.html?q=type%3AGuide%20a%20b"
    test "$(${docs}/bin/campground --browser echo --theme navy-mk2-light)" = "file://${site}/index.html?theme=navy-mk2-light"
    test "$(${docs}/bin/campground --serve --bind 0.0.0.0 --port 9000 --print)" = "http://localhost:9000/index.html"
    if ${docs}/bin/campground --serve --port nope 2>/dev/null; then exit 1; fi
    if ${docs}/bin/campground --browser echo --theme no-such-theme 2>/dev/null; then exit 1; fi
    if ${docs}/bin/campground --browser echo no-such-page.html 2>/dev/null; then exit 1; fi
    if ${docs}/bin/campground --browser no-such-browser 2>/dev/null; then exit 1; fi

    touch $out
  ''
