{ config, pkgs, agenix, ... }:

let
  mysecrets = builtins.fetchGit {
    url = "git@gitlab.com:usmcamp0811/campground-secrets.git";
    ref = "master"; 
    rev = "955a4322b58a027a6eba938150452b485153b7dd"; 
  };
in
{
  imports = [
     agenix.nixosModules.default
  ];

  environment.systemPackages = [
    agenix.packages."x86_64-linux".default
  ];

  age.secrets."test" = {
    # whether secrets are symlinked to age.secrets.<name>.path
    symlink = true;
    # target path for decrypted file
    path = "/etc/some-secret-file";
    # encrypted file path
    file =  "${mysecrets}/test.age";  # refer to ./xxx.age located in `mysecrets` repo
    mode = "0400";
    owner = "root";
    group = "root";
  };
}


