{
  pkgs,
  lib,
  ...
}: let
  ps = pkgs.python3Packages;

  # PyTorch comes from the upstream wheels (`torch-bin`) rather than nixpkgs'
  # source build, because the cached nixpkgs `torch` is CPU-only and a local
  # CUDA source build is a multi-hour job.
  #
  # The swap is applied as a *targeted* override on just the packages that
  # actually consume torch. The tempting alternative --
  #   python3.override { self = python; packageOverrides = ...; }
  # -- rebuilds the entire Python package set (48 derivations here, including
  # unrelated things like cython and seaborn) because every package ends up
  # referencing the overridden `self`. Overriding only the three real consumers
  # keeps everything else on the binary cache and cuts that to 8 derivations.
  #
  # All three must be overridden together: leaving any of them on the stock
  # `torch` would put two different torch builds in the same environment, which
  # collides at buildEnv time.
  torchBin = ps.torch-bin;
  torchvisionBin = ps.torchvision-bin;

  thopBin = ps.ultralytics-thop.override {torch = torchBin;};

  ultralyticsBin = ps.ultralytics.override {
    torch = torchBin;
    torchvision = torchvisionBin;
    ultralytics-thop = thopBin;
  };

  pythonEnv = pkgs.python3.withPackages (_: [
    ultralyticsBin
    torchBin
    torchvisionBin
    ps.opencv4
    ps.numpy
    ps.lap # ByteTrack's linear-assignment solver
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
