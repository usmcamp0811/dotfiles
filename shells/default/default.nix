{ mkShell
, pkgs
, flaskApp # Assuming flaskApp is the attribute name of your Flask package
, ...
}:
mkShell {
  buildInputs = with pkgs; [
    deadnix
    hydra-check
    nix-diff
    nix-index
    nix-prefetch-git
    nixpkgs-fmt
    nixpkgs-hammering
    nixpkgs-lint
    snowfallorg.flake
    statix
    flaskApp # Add your Flask app here
  ];

  shellHook = ''
    echo 🏕️ Welcome to the Campground
    echo 🌐 Starting Flask app...
    export FLASK_APP=$out/bin/app.py # Set the FLASK_APP environment variable
    flask run # Optionally, run the Flask app
  '';
}
