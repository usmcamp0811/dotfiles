{ pkgs
, lib
, inputs
, ...
}:
let
  sassEmbeddedLinux =
    let
      dartFHS = pkgs.buildFHSEnv {
        name = "dart-wrapper";
        targetPkgs = pkgs: [ pkgs.dart ];
        runScript = "${pkgs.dart}/bin/dart";
      };
    in
    pkgs.stdenv.mkDerivation rec {
      pname = "sass-embedded-linux-x64";
      version = "1.71.1";

      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/sass-embedded-linux-x64/-/sass-embedded-linux-x64-${version}.tgz";
        sha512 = "sha512-7BXniYic16+MQx0InyH8OXburLPGMRYRWf0l/t/fRkNkUHWFl7NQPAX0yvj73c/PKOdaYEUY6isNB4OGUGtZHQ==";
      };

      installPhase = ''
            mkdir -p $out/lib/node_modules/sass-embedded-linux-x64
            tar --strip-components=1 -xzf $src -C $out/lib/node_modules/sass-embedded-linux-x64

            mkdir -p $out/lib/node_modules/sass-embedded-linux-x64/dart-sass/src
            cat > $out/lib/node_modules/sass-embedded-linux-x64/dart-sass/src/dart <<EOF
            #!${pkgs.runtimeShell}
            exec ${dartFHS}/bin/dart "\$@"
        EOF
            chmod +x $out/lib/node_modules/sass-embedded-linux-x64/dart-sass/src/dart
      '';

      meta = with pkgs.lib; {
        description = "Sass embedded with Dart in FHS for working IPC";
        homepage = "https://github.com/sass/embedded-host-node";
        license = licenses.mit;
      };
    };
in
pkgs.stdenv.mkDerivation rec {
  pname = "sass-embedded";
  version = "1.71.1";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/sass-embedded/-/sass-embedded-${version}.tgz";
    sha512 = "sha512-nOmqErO1zd1wjvTbDscLZZ3fv5JPeQfaKuo0UCjYm7qPbpQcycp0l3nFZHxovjLjCetJ9IrLOADdznFYKV0f1A==";
  };

  installPhase = ''
    mkdir -p $out/lib/node_modules/${pname}/node_modules
    tar --strip-components=1 -xzf $src -C $out/lib/node_modules/${pname}

    cp -r ${sassEmbeddedLinux}/lib/node_modules/sass-embedded-linux-x64 \
      $out/lib/node_modules/${pname}/node_modules/

    mkdir -p $out/bin
    ln -s $out/lib/node_modules/${pname}/bin/sass-embedded.js $out/bin/sass-embedded
  '';

  meta = with lib; {
    description = "Embedded Sass implementation for Node (with embedded compiler)";
    homepage = "https://github.com/sass/embedded-host-node";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
