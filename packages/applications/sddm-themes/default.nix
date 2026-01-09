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
    version = "unstable-2024-11-15";

    src = fetchFromGitHub {
      owner = "lifeashansen";
      repo = "sddm-nixos";
      rev = "5e39e0841d4942757079779b4f0087f921288af6";
      sha256 = "sha256-bqMnJs59vWkksJCm+NOJWgsuT4ABSyIZwnABC3JLcSc=";
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

      # Create individual theme directories for each configuration
      for themeConf in Themes/*.conf; do
        themeName=$(basename "$themeConf" .conf)
        themeDir="$out/share/sddm/themes/$themeName"

        mkdir -p "$themeDir"

        # Copy all shared resources to each theme
        cp -r Assets "$themeDir/"
        cp -r Backgrounds "$themeDir/"
        cp -r Components "$themeDir/"
        cp -r Fonts "$themeDir/"

        # Copy the Main.qml and metadata
        cp Main.qml "$themeDir/"
        cp "$themeConf" "$themeDir/theme.conf"

        # Create metadata.desktop for this theme
        cat > "$themeDir/metadata.desktop" <<EOF
[SddmGreeterTheme]
Name=$themeName
Description=Beautiful SDDM theme - $themeName variant
Author=lifeashansen
Copyright=GPL3+
License=GPL3+
Type=sddm-theme
Version=1.0
Theme-Id=$themeName
Theme-API=2.0
ConfigFile=theme.conf
MainScript=Main.qml
EOF
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
