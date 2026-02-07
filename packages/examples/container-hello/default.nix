{ lib
, writeText
, writeShellApplication
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;

  new-meta = with lib; {
    description = "Hello World Docker Image";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };

  scriptContent = pkgs.writeText "entrypoint.sh" ''
    #!/bin/sh
    echo "Hello, this is the entrypoint script."
    ${pkgs.cowsay}/bin/cowsay "yut yut"
    # exec "$@"
  '';

  hello-image =
    let
      l1 = pkgs.dockerTools.buildImage {
        name = "layer-1";
        tag = "latest";
        extraCommands = ''
          mkdir -p config/bin
          cat ${scriptContent} > config/bin/entrypoint.sh
          chmod +x config/bin/entrypoint.sh
        '';
      };
      l2 = pkgs.dockerTools.buildImage {
        name = "layer-2";
        fromImage = l1;
        tag = "latest";
        extraCommands = ''
          mkdir -p config
          echo "Hello World" > config/hello.txt
        '';
      };
    in
    pkgs.dockerTools.buildImage {
      name = "layer-3";
      fromImage = l2;
      tag = "latest";
      copyToRoot = pkgs.buildEnv {
        name = "image-root";
        pathsToLink = [ "/bin" ];
        paths = [ pkgs.coreutils pkgs.ranger pkgs.neovim ];
      };
      extraCommands = ''
        mkdir -p tmp
        echo Layer3 > tmp/layer3
      '';
      config = {
        Env = [
          "PATH=${pkgs.coreutils}/bin/:${pkgs.ranger}/bin/:${pkgs.neovim}/bin/"
        ];
        WorkingDir = "/config/bin";
        Cmd = [ "${pkgs.bash}/bin/bash" "/config/bin/entrypoint.sh" ];
      };
    };
in
override-meta new-meta hello-image
