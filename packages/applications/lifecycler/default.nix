{ lib, pkgs, ... }:

let
  version = "v0.2.9";
  src = pkgs.fetchFromGitHub {
    owner = "cxreiff";
    repo = "lifecycler";
    tag = version;
    sha256 = "sha256-VYP3BfA9GdlnCf4F4h//NJG4FMoLG7OpPfZfeP2RFMM=";
  };

  lifecycler = pkgs.rustPlatform.buildRustPackage {
    pname = "lifecycler";
    inherit src version;

    cargoLock.lockFile = "${src}/Cargo.lock";

    cargoLock.outputHashes = {
      "zune-jpeg-0.4.11" =
        "sha256-Iks3Gslg+LcGIWQL2K3SfGTKxamlYv8SiRfq14kW/pE="; # Replace with correct hash
    };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.alsa-lib
      pkgs.systemd
      pkgs.vulkan-loader # Vulkan loader
      pkgs.vulkan-validation-layers
      pkgs.libGL
      pkgs.mesa
    ];

    LD_LIBRARY_PATH =
      lib.makeLibraryPath [ pkgs.vulkan-loader pkgs.mesa.drivers pkgs.libGL ];
  };

in
lifecycler
