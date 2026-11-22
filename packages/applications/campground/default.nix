{
  pkgs,
  lib,
  inputs,
  ...
}:
# Campground's authored bundles and generated NixOS options as a static website.
#
#   nix run .#campground                          # open it in a browser
#   nix run .#campground -- --search 'vault'      # open the search page
#   nix run .#campground -- --theme navy-mk2-light
#   nix run .#campground -- --browser qutebrowser
#   nix run .#campground -- --print               # print the file:// URL only
#
# Authored documents are filtered to markdown/images; options are regenerated
# from module schemas when their declarations change.
let
  root = ../../..;
  sourceBundles = ["docs" "modules" "systems"];
  options = import ./options.nix {inherit pkgs inputs;};
  images = ["png" "jpg" "jpeg" "gif" "svg" "webp"];
  wanted = file: file.hasExt "md" || lib.any (ext: file.hasExt ext) images;
in
  pkgs.fmf.okf.mkSite {
    name = "campground";
    title = "Campground";
    subtitle = "A NixOS flake you can install from, build on or learn from: modules, hosts, templates and runbooks.";
    # The first page is the front door; the others are the cards under "Where to go next".
    start = [
      "docs/START-HERE.md"
      "docs/INSTALL-NIXOS.md"
      "docs/DOWNSTREAM-FLAKE.md"
      "docs/NEW-SYSTEM.md"
      "docs/HOW-FMF-WORKS.md"
      "docs/COMMON-TASKS.md"
      "docs/LevelUp.md"
    ];
    # How the documentation itself is built and checked; linked from "Browse the library".
    about = "docs/OKF.md";
    repo = "https://gitlab.com/usmcamp0811/dotfiles";
    bundles = sourceBundles ++ ["options"];
    src = pkgs.runCommand "campground-documentation" {} ''
      mkdir -p $out
      cp -r ${lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.unions (map (bundle: lib.fileset.fileFilter wanted (root + "/${bundle}")) sourceBundles);
    }}/. $out/
      cp -r ${options}/options $out/options
    '';
  }
