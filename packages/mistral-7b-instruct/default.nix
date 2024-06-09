{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  name = "mistral-7b-instruct";

  # jar-version = "3.0.2-1.18";
  # sha256 = "sha256-b9NgGdoshvz4VFj0N2F6vKWjQnwjAoJg99OQ6tidnVI=";
  version = "0.1.Q4_K_M";

  mistral-model = pkgs.fetchurl {
    url =
      "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/raw/main/mistral-7b-instruct-v${version}.gguf";
    sha256 = "";
  };
in mistral-model
