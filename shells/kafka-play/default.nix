{ mkShell, pkgs, ... }:
mkShell {
  buildInputs = with pkgs; [ julia.withPackages [ "RDKafka" ] ];

  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"

    # Additional setup can go here
  '';
}
