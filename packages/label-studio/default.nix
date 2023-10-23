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
    chdir = /label-studio/label_studio
    http = [::]:8000
    module = server:application
    master = true
    cheaper = true
    single-interpreter = true
    processes = 4
    vacuum = true
    die-on-term = true
    pidfile = /tmp/%n.pid
    buffer-size = 65535
    http-timeout = 300
    stats = :1717
    stats-http = true
    memory-report = true
    auto-procname = true
    procname-prefix = ls-
    need-app = true
    env = APP_WEBSERVER=uwsgi
    ignore-sigpipe = true
    ignore-write-errors = true
    disable-write-exception = true
    post-buffering = 4096
    disable-logging = True
    log-5xx = true
    skip-atexit-teardown = True
    enable-threads = True
    thunder-lock = True
    lazy-apps = True
    reload-on-rss = 1024
    max-worker-lifetime = 1200
    max-worker-lifetime-delta = 60
    harakiri = 91
    harakiri-verbose = true
    reload-mercy = 3
    worker-reload-mercy = 3
  '';

  label-studio = pkgs.stdenv.mkDerivation {
    pname = "label-studio";
    version = "1.9.0";
    src = pkgs.label_studio;
    buildInputs = [ uwsgiWithPython3 ];

    installPhase = ''
      install -Dm644 ${uwsgiConfig} $out/etc/uwsgi.ini
      echo "#!/bin/sh" > $out/bin/run-label-studio
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
