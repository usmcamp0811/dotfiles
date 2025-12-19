{ lib, pkgs, ... }:
let

  example = pkgs.streamLayeredImageConf {
    name = "flakeforge-example-container";
    tag = "latest";
    contents = [ pkgs.fmf.blog.server ];
    config = {
      Entrypoint = [ "hugo-server" ];
    };
  };

in
example
