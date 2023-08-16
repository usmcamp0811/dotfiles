{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.firefox;
in
{
  options.campground.apps.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Firefox.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nssTools
      firefox
    ];

    # TODO: Add things to exploade cac certs and install them into firefox here
    campground.services.cac.enable = mkIf cfg.cac true;
  };
}

# TODO: Read this and do something with it
# https://github.com/NixOS/nixpkgs/issues/171978
# Firefox needs to be convinced to use p11-kit-proxy by running a command like this:
#
# modutil -add p11-kit-proxy -libfile ${p11-kit}/lib/p11-kit-proxy.so -dbdir ~/.mozilla/firefox/*.default
# I was also able to accomplish the same by making use of extraPolciies when overriding the firefox package:
#
#         extraPolicies = {
#           SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
#         };
