{ pkgs, lib, ... }:

let
  configs = builtins.attrNames (builtins.readDir ./dotfiles);
  mkDotfile = name: src:
    let
      fileName = builtins.baseNameOf src;
      pkg = pkgs.stdenvNoCC.mkDerivation {
        inherit name src;

        dontUnpack = true;

        installPhase = ''
          cp $src $out
        '';

        passthru = { inherit fileName; };
      };
    in
    pkg;
  names = builtins.map (lib.snowfall.path.get-file-name-without-extension) configs;
  dotfiles = lib.foldl
    (acc: config:
      let
        # fileName = builtins.baseNameOf config;
        # lib.getFileName is a helper to get the basename of
        # the file and then take the name before the file extension.
        # eg. mywallpaper.png -> mywallpaper
        name = lib.snowfall.path.get-file-name-without-extension config;
      in
      acc // { "${name}" = mkDotfile name (./dotfiles + "/${config}"); })
    { }
    configs;
  installTarget = "$out/share/dotfiles";
  installDotfiles = builtins.mapAttrs
    (name: wallpaper: ''
      cp ${wallpaper} ${installTarget}/${wallpaper.fileName}
    '')
    dotfiles;
in
pkgs.stdenvNoCC.mkDerivation {
  name = "campground-dotfiles";
  src = ./dotfiles;

  installPhase = ''
    mkdir -p ${installTarget}

    find * -type f -mindepth 0 -maxdepth 0 -exec cp ./{} ${installTarget}/{} ';'
  '';

  passthru = { inherit names; } // dotfiles;
}
