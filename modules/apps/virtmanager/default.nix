{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.virtmanager;
in
{
  options.campground.apps.virtmanager = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virt-manager.";
  };

  config = mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.dconf.enable = true;
    environment.systemPackages = with pkgs; [ virt-manager spice_gtk ];
    security.wrappers.spice-client-glib-usb-acl-helper.source = "${pkgs.spice_gtk}/bin/spice-client-glib-usb-acl-helper";
    # TODO: Move to user config
    campground.home.extraOptions = {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
    };
    campground.user.extraGroups = [ "libvirtd" ];

  };
}
