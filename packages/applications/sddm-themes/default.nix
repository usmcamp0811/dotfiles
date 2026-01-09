{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  ...
}:
let
  themeName = "astronaut";  # Base theme name from the repository
in
stdenv.mkDerivation rec {
  pname = "sddm-theme-${themeName}";
  version = "unstable-2024-11-15";

  src = fetchFromGitHub {
    owner = "lifeashansen";
    repo = "sddm-nixos";
    rev = "5e39e0841d4942757079779b4f0087f921288af6";
    sha256 = "sha256-vJ9K8yjLOE/OVpV0Pj8krAh6CIxWR+SiGjEgnrNPHNY=";
  };

  dontBuild = true;
  dontConfigure = true;

  propagatedBuildInputs = [
    qt6.qtsvg
    qt6.qtdeclarative
    qt6.qt5compat
    qt6.qtmultimedia
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/sddm/themes

    # Install all themes from the Themes directory
    for theme in Themes/*; do
      if [ -d "$theme" ]; then
        themeName=$(basename "$theme")
        mkdir -p $out/share/sddm/themes/$themeName
        cp -r "$theme"/* $out/share/sddm/themes/$themeName/
      fi
    done

    # Copy shared assets
    mkdir -p $out/share/sddm/themes/shared
    cp -r Assets $out/share/sddm/themes/shared/ || true
    cp -r Backgrounds $out/share/sddm/themes/shared/ || true
    cp -r Components $out/share/sddm/themes/shared/ || true
    cp -r Fonts $out/share/sddm/themes/shared/ || true

    # Make sure each theme has access to shared resources
    for theme in $out/share/sddm/themes/*; do
      if [ -d "$theme" ] && [ "$(basename $theme)" != "shared" ]; then
        ln -sf ../shared/Assets "$theme/Assets" 2>/dev/null || true
        ln -sf ../shared/Backgrounds "$theme/Backgrounds" 2>/dev/null || true
        ln -sf ../shared/Components "$theme/Components" 2>/dev/null || true
        ln -sf ../shared/Fonts "$theme/Fonts" 2>/dev/null || true
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Collection of beautiful SDDM themes with Qt6 support";
    homepage = "https://github.com/lifeashansen/sddm-nixos";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [];
  };
}
