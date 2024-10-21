{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  awrit = pkgs.stdenv.mkDerivation rec {
    pname = "awrit";
    version = "main"; # Change this to a specific version if needed

    src = fetchFromGitHub {
      owner = "chase";
      repo = "awrit";
      rev = "main";
      sha256 = "";
    };

    buildInputs = [ pkgs.cmake pkgs.ninja ];

    buildPhase = ''
      cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release -S . -B build
      cmake --build build
    '';

    installPhase = ''
      cmake --install build --prefix $out
      wrapProgram $out/bin/awrit --prefix PATH : ${
        stdenv.lib.makeBinPath buildInputs
      }
    '';

    meta = with lib; {
      description = "Actual Web Rendering in Terminal";
      homepage = "https://github.com/chase/awrit";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  new-meta = with lib; {
    description = "A Kafka Headquarters";
    homepage = "https://github.com/tchiotludo/awrit";
    license = pkgs.lib.licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta awrit
