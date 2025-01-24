{ pkgs, ... }:

pkgs.mkShell {
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

  src = pkgs.fetchFromGitHub {
    owner = "Xoconoch";
    repo = "zotifarr";
    rev = "main";
    sha256 = "";
  };

  shellHook = ''
    echo "Setting up environment..."

    # Create necessary directories
    mkdir -p /var/log
    touch /var/log/dockerd.log
    mkdir -p ./credentials
    mkdir -p ./downloads

    # Export environment variables
    export FLASK_APP=app.py
    export FLASK_RUN_HOST=0.0.0.0

    echo "Environment setup complete."
  '';

  meta = {
    description = "Python Flask application with utilities.";
    license = pkgs.lib.licenses.mit;
    maintainers = [ "your-github-username" ];
  };
}
