{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.jellyfin;
in {
  options.fmf.services.jellyfin = {
    enable = mkEnableOption "Jellyfin";
  };

  config = mkIf cfg.enable {
    # nixpkgs.config.packageOverrides = pkgs: {
    #   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    # };

    users.users.jellyfin = {
      isSystemUser = true;
      extraGroups = ["users"]; # TODO: change to a different group
    };

    # users.groups.ldap-user = {
    #   gid = 10000;
    # };

    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };
}
