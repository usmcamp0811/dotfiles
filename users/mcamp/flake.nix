{
  # Import the necessary flake
  inputs.plusultra.url = "github:jakehamilton/config";

  outputs = { self, nixpkgs, plusultra, ... }: let
    system = "x86_64-linux";  # Define the system here
  in
  {
    homeConfigurations = {
      mcamp = { config, pkgs, ... }: {
        # Import the home-manager module from the flake
        imports = [ plusultra.nixosModules.home-manager ];

        # Use the applications defined in the flake
        programs.firefox.enable = true;
        programs.vscode.enable = true;

        # Specify the user for home-manager
        home.username = "mcamp";
        home.homeDirectory = "/home/mcamp";

        # Use the user packages from the flake
        home.packages = with plusultra.packages.${system}; [ firefox vscode ];

        # Use the home-manager options from the flake
        plusultra.home.file = {
          ".config/somefile".text = "contents of somefile";
        };
        plusultra.home.configFile = {
          "someconfig".text = "contents of someconfig";
        };
      };
    };
  };
}

