{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  ...
}: let
  themeName = "astronaut"; # Base theme name from the repository
in
  stdenv.mkDerivation rec {
    pname = "sddm-theme-${themeName}";
    version = "unstable-2025-12-06";

    # Using a working fork since the original repository was deleted
    src = fetchFromGitHub {
      owner = "Keyitdev";
      repo = "sddm-astronaut-theme";
      rev = "d73842c761f7d7859f3bdd80e4360f09180fad41";
      sha256 = "sha256-+94WVxOWfVhIEiVNWwnNBRmN+d1kbZCIF10Gjorea9M=";
    };

    dontBuild = true;
    dontConfigure = true;
    dontWrapQtApps = true;

    propagatedBuildInputs = [
      qt6.qtsvg
      qt6.qtdeclarative
      qt6.qt5compat
      qt6.qtmultimedia
    ];

    installPhase = ''
      runHook preInstall

      # Create theme directory
      themeDir="$out/share/sddm/themes/sddm-astronaut-theme"
      mkdir -p "$themeDir"

      # Copy all theme files
      cp -r * "$themeDir/"

      # Create metadata.desktop if it doesn't exist
      if [ ! -f "$themeDir/metadata.desktop" ]; then
        cat > "$themeDir/metadata.desktop" <<EOF
[SddmGreeterTheme]
Name=Astronaut
Description=Beautiful SDDM astronaut theme with Qt6 support
Author=Keyitdev
Copyright=GPL3+
License=GPL3+
Type=sddm-theme
Version=1.0
Theme-Id=sddm-astronaut-theme
Theme-API=2.0
ConfigFile=theme.conf
MainScript=Main.qml
EOF
      fi

      runHook postInstall
    '';

    meta = with lib; {
      description = "Beautiful SDDM astronaut theme with Qt6 support";
      homepage = "https://github.com/Keyitdev/sddm-astronaut-theme";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
      maintainers = [];
    };
  }
