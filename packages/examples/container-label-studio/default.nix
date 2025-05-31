{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground; let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  # allows us to just use the app/package
  # inherit (pkgs.campground) campground;

  new-meta = with lib; {
    description = "A Simple label-studio App Container Image";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

  container-label-studio = pkgs.dockerTools.buildLayeredImage {
    name = "label-studio-app";
    tag = "latest";
    contents = [ pkgs.label_studio pkgs.bash pkgs.coreutils ];
    extraCommands = ''
      mkdir -p usr/bin
      cat ${pkgs.label_studio}/bin/label-studio > usr/bin/label-studio
      chmod +x usr/bin/label-studio
    '';
    config = {
      Entrypoint = [ "label-studio" ];
      ExposedPorts = { "8080/tcp" = { }; };
      Env = [ "PATH=${pkgs.coreutils}/bin/:/usr/bin/" ];
    };
  };
in
override-meta new-meta container-label-studio
