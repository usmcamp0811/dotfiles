{ mkShell, pkgs, ... }:
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
    fmf.example-flask-app # Add your Flask app here
  ];

  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[34m| run-flask-app  \e[0m - \e[37mTo start Flask with uWSGI               |\e[0m"
    echo -e "\e[34m| dev-flask-app  \e[0m - \e[37mTo run the Flask dev server.            |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"

    # Additional setup can go here
  '';
}
