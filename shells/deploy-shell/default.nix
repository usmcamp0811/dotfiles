{ mkShell, pkgs, ... }:
mkShell {
  buildInputs = with pkgs; [ vault-bin deploy-rs campground.vault-scripts ];

  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|       🏕️  Welcome to the Campground Deploy Shell          |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[34m|    A shell to help get new systems deployed from zero.    |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
  '';
}
