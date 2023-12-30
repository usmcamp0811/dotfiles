{ config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.nixery;
  description = "Nixery";
  storagePath = "/var/lib/nixery";
in
{
  options.campground.services.nixery = with types; {
    enable = mkBoolOpt false "Whether or not to enable nixery.";
  };

  config = mkIf cfg.enable {
    # systemd.services.nixery = {
    #   inherit description;
    #   wantedBy = [ "multi-user.target" ];
    #
    #   serviceConfig = {
    #     DynamicUser = true;
    #     StateDirectory = "nixery";
    #     Restart = "always";
    #     ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${storagePath}";
    #     ExecStart = "${nixery-pkgs.nixery}/bin/server";
    #   };
    #
    #   environment = {
    #     PORT = "8080";
    #     NIXERY_PKGS_PATH = pkgs.path;
    #     NIXERY_STORAGE_BACKEND = "filesystem";
    #     NIX_TIMEOUT = "60";
    #     STORAGE_PATH = storagePath;
    #     WEB_DIR = "/dev/null";
    #   };
    # };
  };
}

