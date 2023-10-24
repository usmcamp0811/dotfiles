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

  uwsgiWithPython3 = pkgs.uwsgi.override {
    plugins = [ "python3" ];
  };

  uwsgiConfig = writeText "uwsgi.ini" ''
    [uwsgi]
    chdir = ${pkgs.label_studio}/lib/python3.10/site-packages/label_studio
    http = [::]:8000
    wsgi-file = ${pkgs.label_studio}/lib/python3.10/site-packages/label_studio/core/wsgi.py
    callable = application
    # module = core.wsgi:application
    # master = true
    # cheaper = true
    # single-interpreter = true
    # log-level = 4
    # vacuum = true
    # die-on-term = true
    # pidfile = /tmp/%n.pid
    # buffer-size = 65535
    # http-timeout = 300
    # stats = :1717
    # stats-http = true
    # reload-mercy = 3
    # worker-reload-mercy = 3
  '';

  label-studio = pkgs.stdenv.mkDerivation {
    pname = "label-studio";
    version = "1.9.0";
    src = pkgs.label_studio;
    buildInputs = [ uwsgiWithPython3 ];

    installPhase = ''
      mkdir -p $out/bin
      install -Dm644 ${uwsgiConfig} $out/etc/uwsgi.ini
      echo "#!/bin/sh" > $out/bin/run-label-studio
      echo "export PATH=${pkgs.label_studio.pyEnv}/bin:$PATH" >> $out/bin/run-label-studio
      echo "export PYTHONPATH=${pkgs.label_studio.pyEnv}" >> $out/bin/run-label-studio
      echo "${uwsgiWithPython3}/bin/uwsgi --ini $out/etc/uwsgi.ini" >> $out/bin/run-label-studio
      chmod +x $out/bin/run-label-studio
    '';
  };

  new-meta = with lib; {
    description = "WGSI Wrapped Label Studio";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta label-studio
