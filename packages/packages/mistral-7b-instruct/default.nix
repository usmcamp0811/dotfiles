{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;

  name = "mistral-7b-instruct";

  version = "0.1.Q4_K_M";

  mistral-model = pkgs.fetchurl {
    url = "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/raw/main/mistral-7b-instruct-v${version}.gguf";
    sha256 = "sha256-0UK4Qw6ZBhnpS3WK5/gZWlf6Ek7A6lF6I6eV1949UHE=";
  };
in
mistral-model
