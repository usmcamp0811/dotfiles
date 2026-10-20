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
#   nix run .#campground -- --theme lantern
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
    subtitle = "The fmf flake: modules, hosts and runbooks, read from their source files.";
    start = "docs/OKF.md";
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
