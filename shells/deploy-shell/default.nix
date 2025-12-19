{ mkShell, pkgs, ... }:
mkShell {
  buildInputs = with pkgs; [ vault-bin deploy-rs fmf.vault-scripts ];

  shellHook = ''
    clear
    echo -e "\e[1;32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[1;32m|       🏕️  Welcome to the Campground Deploy Shell          |\e[0m"
    echo -e "\e[1;32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[1;36m|     🚀 Ready to deploy and configure your systems!        |\e[0m"
    echo -e "\e[1;34m|      Quick Commands:                                      |\e[0m"
    echo -e "\e[1;34m|      🔹 deploy --hostname <hostname|ip>                   |\e[0m"
    echo -e "\e[1;34m|          gitlab:usmcamp0811/dotfiles#<hostname>           |\e[0m"
    echo -e "\e[1;34m|          --skip-checks                                    |\e[0m"
    echo -e "\e[1;36m|                                                           |\e[0m"
    echo -e "\e[1;36m|     🌐 Documentation and help available if needed.        |\e[0m"
    echo -e "\e[1;32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[1;33mNote: Use this shell to bootstrap and manage deployments.\e[0m"
  '';
}
