{ pkgs
, config
, lib
, self
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib.campground) override-meta;
in
pkgs.devshell.mkShell {
  imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
  env = [
    {
      name = "LD_LIBRARY_PATH";
      value = "${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib";
    }
    {
      name = "EXTRA_LDFLAGS";
      value = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
    }
    {
      name = "EXTRA_CCFLAGS";
      value = "-I/usr/include";
    }
    {
      name = "CUDA_PATH";
      value = "${pkgs.cudatoolkit}";
    }
  ];

}

