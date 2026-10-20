{
  pkgs,
  lib,
  ...
}:
# Campground's docs, modules and systems bundles as a static website.
#
#   nix run .#campground                          # open it in a browser
#   nix run .#campground -- --search 'vault'      # open the search page
#   nix run .#campground -- --theme lantern
#   nix run .#campground -- --browser qutebrowser
#   nix run .#campground -- --print               # print the file:// URL only
#
# Only the markdown and image files are inputs, so this rebuilds only when the
# documentation changes.
let
  root = ../../..;
  bundles = ["docs" "modules" "systems"];
  images = ["png" "jpg" "jpeg" "gif" "svg" "webp"];
  wanted = file: file.hasExt "md" || lib.any (ext: file.hasExt ext) images;
in
  pkgs.fmf.okf.mkSite {
    name = "campground";
    title = "Campground";
    subtitle = "The fmf flake: modules, hosts and runbooks, read from their source files.";
    start = "docs/OKF.md";
    inherit bundles;
    src = lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.unions (map (bundle: lib.fileset.fileFilter wanted (root + "/${bundle}")) bundles);
    };
  }
