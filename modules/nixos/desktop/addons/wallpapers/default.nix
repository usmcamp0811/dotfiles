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
  options.fmf.desktop.addons.wallpapers = with types; {
    enable =
      mkBoolOpt false
        "Whether or not to add wallpapers to ~/Pictures/wallpapers.";
  };
  # TODO: Make this mine....
  config = {
    fmf.home.file = lib.foldl'
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
