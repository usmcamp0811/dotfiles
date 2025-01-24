{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  pname = "zotifarr";
  version = "1.0.0"; # Replace with the actual version if known

  src = pkgs.fetchFromGitHub {
    owner = "Xoconoch";
    repo = "zotifarr";
    rev = "main";
    sha256 = "sha256-aVAnvcolmKw2DMGu5ptgQiwDSFUy6JtbPPrV7FzDCW8=";
  };

  buildInputs = [
    (pkgs.python311.withPackages (ps: [
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
    ]))
    pkgs.iptables
    pkgs.nano
    pkgs.curl
    pkgs.gnupg
    pkgs.lsb-release
  ];

  installPhase = ''
    mkdir -p $out/app
    cp -r * $out/app
  '';

  meta = {
    description = "Python Flask application with utilities.";
    license = pkgs.lib.licenses.mit;
    maintainers = [ "your-github-username" ];
  };
}
