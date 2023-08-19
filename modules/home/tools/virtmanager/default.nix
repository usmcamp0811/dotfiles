{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.tools.virtmanager;
in
{
  options.campground.tools.virtmanager = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virt-manager.";
  };

  config = mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.dconf.enable = true;
    home.packages = with pkgs; [ virt-manager spice-gtk ];
    # security.wrappers.spice-client-glib-usb-acl-helper.source = "${pkgs.spice_gtk}/bin/spice-client-glib-usb-acl-helper";
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
