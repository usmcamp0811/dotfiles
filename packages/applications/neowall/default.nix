{
  lib,
  pkgs,
  ...
}: let
  pname = "neowall";
  owner = "1ay1";
  repo = pname;
  description = "GPU-Accelerated Live Wallpapers for Wayland & X11";

  # Table of versions and hashes
  versions = {
    v0-4-0 = {
      version = "0.4.0";
      hash = "sha256-dgCsdAuzjRh0UufuV/sQhw0QoFTIw25vBwESIXNY8Y4=";
    };
    v0-4-1 = {
      version = "0.4.1";
      hash = "sha256-Ybms3++7ql5X/xxfUywp6ClxA7rKlzHYfb13yhORR7E=";
    };
  };

  # Common builder
  mkNeowall = {
    version,
    hash,
  }:
    pkgs.stdenv.mkDerivation {
      inherit pname version;

      src = pkgs.fetchFromGitHub {
        inherit owner repo hash;
        rev = "v${version}";
      };

      meta = {
        inherit description;
        homepage = "https://github.com/${owner}/${repo}";
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };

      nativeBuildInputs = [
        pkgs.pkg-config
        pkgs.wayland-protocols
      ];

      buildInputs = with pkgs; [
        libjpeg
        libpng
        wayland
        mesa # GLES2 bits
        libglvnd # EGL / GL loader (needed for egl.pc etc.)
        xorg.libX11
        xorg.libXrandr
      ];

      buildPhase = ''
        make -j${toString (pkgs.stdenv.hostPlatform.parsed.cpu.cores or 1)}
      '';

      installPhase = ''
        mkdir -p "$out/bin"
        install -m 555 build/bin/neowall "$out/bin/neowall"

        # install bundled shaders
        if [ -d examples/shaders ]; then
          mkdir -p "$out/share/shaders"
          cp -r examples/shaders/* "$out/share/shaders/"
        fi
      '';
    };

  # Build a derivation for each version
  drvs = lib.mapAttrs (_name: mkNeowall) versions;

  # Pick the "latest" version explicitly
  latest = drvs.v0-4-1;
in
  # Default output is the latest derivation,
  # but you also get attrs like `.v0-4-0` and `.v0-4-1`
  latest // drvs
