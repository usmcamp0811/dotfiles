{ options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.fmf; let
  inherit (pkgs.fmf) wallpapers;
in
{
  options.fmf.desktop.wallpapers = with types; {
    enable =
      mkBoolOpt false
        "Whether or not to add wallpapers to ~/Pictures/wallpapers.";
  };
  config = {
    home.file = lib.foldl
      (acc: name:
        let
          wallpaper = wallpapers.${name};
        in
        acc
        // {
          "Pictures/wallpapers/${wallpaper.fileName}".source = wallpaper;
        })
      { }
      (wallpapers.names);
  };
}
