# import & decrypt secrets in `mysecrets` in this module
{ options, config, pkgs, lib, agenix, mysecrets, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.secrets;

in
{
  imports = [
     agenix.nixosModules.default
  ];

  environment.systemPackages = [
    agenix.packages."x86_64-linux".default
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
}
