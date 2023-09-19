{ mkShell
, pkgs
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
    campground.flask-app # Add your Flask app here
  ];

  shellHook = ''
    echo 🏕️ Welcome to the Campground
    # Additional setup can go here
  '';
}
