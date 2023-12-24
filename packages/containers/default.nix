{ lib
, writeText
, writeShellApplication
, substituteAll
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  inherit (pkgs.nix-snapshotter) buildImage;

  # new-meta = with lib; {
  #   description = "Hello World Docker Image";
  #   license = licenses.asl20;
  #   maintainers = with maintainers; [ mattcamp ];
  # };

      examples = rec {
        hello = buildImage {
          name = "ghcr.io/aicampground/my-hello2";
          tag = "latest";
          config = {
            entrypoint = ["${pkgs.hello}/bin/hello"];
          };
        };

        redis = buildImage {
          name = "ghcr.io/pdtpartners/my-redis";
          tag = "latest";
          config = {
            entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
          };
        };

        mlflow = buildImage {
          name = "aicampground.com/testing/mlflow";
          tag = "latest";
          config = {
            entrypoint = [ "${pkgs.campground.mlflow}/bin/mlflow-server" ];
          };
        };

        redisWithShell = buildImage {
          name = "ghcr.io/pdtpartners/redis-shell";
          tag = "latest";
          fromImage = redis;
          config = {
            entrypoint = [ "/bin/sh" ];
          };
          copyToRoot = pkgs.buildEnv {
            name = "system-path";
            pathsToLink = [ "/bin" ];
            paths = [
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.redis
            ];
          };
        };
      };
in 
examples.redisWithShell

