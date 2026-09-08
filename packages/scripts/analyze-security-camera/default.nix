{
  pkgs,
  lib,
  ...
}: let
  # Use the upstream PyTorch wheels: they ship CUDA, are in the binary cache, and
  # avoid a multi-hour local CUDA rebuild. The packageOverrides + `self` idiom
  # makes the swap propagate to every transitive consumer (ultralytics, thop,
  # torchvision) so only one `torch` ends up in the environment.
  python = pkgs.python3.override {
    self = python;
    packageOverrides = _final: prev: {
      torch = prev.torch-bin;
      torchvision = prev.torchvision-bin;
      torchaudio = prev.torchaudio-bin;
    };
  };

  pythonEnv = python.withPackages (ps:
    with ps; [
      ultralytics
      opencv4
      numpy
      lap # ByteTrack's linear-assignment solver
      torch
      torchvision
    ]);

  # Pinned weights so the tool never reaches out to GitHub at runtime.
  yoloWeights = pkgs.fetchurl {
    url = "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11m.pt";
    hash = "sha256-1f/BpnSVOgjhGo0h4CJ4GxsjoZtzCvwwkpC9n7UwW5U=";
  };

  script = ./analyze_security_camera.py;
  calibration = ./calibration.json;
  reference = ./reference.jpg;
in
  pkgs.writeShellApplication {
    name = "analyze-security-camera";

    runtimeInputs = [pkgs.ffmpeg];

    text = ''
      # Ultralytics insists on a writable config dir and will otherwise try to
      # create one inside the read-only nix store.
      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}"
      export YOLO_CONFIG_DIR="''${YOLO_CONFIG_DIR:-$cache_root/ultralytics}"
      export MPLCONFIGDIR="''${MPLCONFIGDIR:-$cache_root/matplotlib}"
      mkdir -p "$YOLO_CONFIG_DIR" "$MPLCONFIGDIR"

      # Never let ultralytics pip-install anything behind our back.
      export YOLO_AUTOINSTALL=false
      export YOLO_OFFLINE=true

      exec ${pythonEnv}/bin/python ${script} \
        --model ${yoloWeights} \
        --calibration ${calibration} \
        --reference ${reference} \
        "$@"
    '';

    meta = with lib; {
      description = "Detect and speed-measure vehicles, cyclists and pedestrians in a security-camera clip";
      longDescription = ''
        Analyses a single clip from the driveway camera and emits a JSON record of
        every vehicle, cyclist and pedestrian seen, including a colour description,
        direction of travel, and an average speed measured by timing each object
        between two calibrated gates placed at the mailboxes (28.8 ft apart).
      '';
      mainProgram = "analyze-security-camera";
      platforms = platforms.linux;
    };
  }
