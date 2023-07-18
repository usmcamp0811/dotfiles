{ options, config, lib, agenix, mysecrets, pkgs, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.apps.agenix;
  mysecrets = builtins.fetchGit {
    url = "https://gitlab.com/usmcamp0811/campground-secrets.git";
    ref = "master"; 
    rev = "57228b7bbd48b88a6660f6d2a9540be893e76976"; 
  };
in
{
  options.campground.apps.agenix = with types; {
    enable = mkBoolOpt false "Whether or not to enable agenix.";
  };

  # TODO: use the rust version and also do the other way not this way.. that uses the github repo
  config =
    mkIf cfg.enable { 
      environment.systemPackages = [ 
        (pkgs.callPackage (builtins.fetchTarball {
          url = "https://github.com/yaxitech/ragenix/archive/main.tar.gz";
          sha256 = "1j9yr5q0453wnmn8941vfppwfsqmx98nk1ajqqw4zjgmkc0kjfbn";
        } + "/pkgs/agenix.nix") {})
      ]; 

      age.secrets."test" = {
        # wether secrets are symlinked to age.secrets.<name>.path
        symlink = true;
        # target path for decrypted file
        path = "/etc/some-secret-file";
        # encrypted file path
        file =  "${mysecrets}/test.age";  # refer to ./xxx.age located in `mysecrets` repo
        mode = "0400";
        owner = "root";
        group = "root";
      };
    };
}
