{ pkgs, ... }:
let
  python-env = pkgs.python311.withPackages (ps: [
    ps.APScheduler
    ps.blinker
    ps.click
    ps.flask
    ps.itsdangerous
    ps.jinja2
    ps.markupsafe
    ps.portalocker
    ps.tenacity
    ps.tzlocal
    ps.werkzeug
  ]);
  src = pkgs.fetchFromGitHub {
    owner = "Xoconoch";
    repo = "zotifarr";
    rev = "main";
    sha256 = "sha256-aVAnvcolmKw2DMGu5ptgQiwDSFUy6JtbPPrV7FzDCW8=";
  };
  run_app = pkgs.writeShellScriptBin "zotifarr" ''
    ${python-env}/bin/python ${src}/app.py $@
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "zotifarr";
  version = "0.1.0";
  inherit src;

  buildInputs = [
    python-env
    pkgs.iptables
    pkgs.nano
    pkgs.curl
    pkgs.gnupg
    pkgs.lsb-release
  ];

  installPhase = ''
    mkdir -p $out/app
    cp -r ${src}/* $out/app
    mkdir -p $out/bin
    cp ${run_app}/bin/zotifarr $out/bin/zotifarr
  '';

  meta = {
    description =
      "Rip from spotify directly to your music library regardless of your account.";
    license = pkgs.lib.licenses.mit;
    maintainers = [ "Matt" ];
  };
}
