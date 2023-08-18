{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
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
    environment.systemPackages = with pkgs; [ virt-manager spice-gtk ];
    security.wrappers.spice-client-glib-usb-acl-helper.source = "${pkgs.spice-gtk}/bin/spice-client-glib-usb-acl-helper";
    # TODO: Move to user config
    campground.home.extraOptions = {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
    };
    campground.user.extraGroups = [ "libvirtd" "usb" ];

   # TODO: Revisit this issue https://github.com/NixOS/nixpkgs/pull/35214
   # let all usb devices be in the usb group
    services.udev.extraRules = ''
      KERNEL=="*", SUBSYSTEMS=="usb", MODE="0664", GROUP="usb"
    ''; 
  };
}
