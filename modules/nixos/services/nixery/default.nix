{ config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.nixery;
  nixery = pkgs.nixery-pkgs.nixery.overrideAttrs (_old: {
    # Drop the nix-1p documentation page as it doesn't build in pure evaluation.
    postInstall = ''
      wrapProgram $out/bin/server \
        --prefix PATH : ${pkgs.nixery-pkgs.nixery-prepare-image}/bin \
        --prefix PATH : ${pkgs.nix}/bin
    '';
  });
in
{
  options.fmf.services.nixery = with types; {
    enable = mkBoolOpt false "Whether or not to enable nixery.";
    port = mkOpt str "4567" "Port to listen on";
    storagePath = mkOpt str "/var/lib/nixery" "Place to store images";
    storageBackend = mkOpt str "filesystem" "Backend";
  };

  config = mkIf cfg.enable {
    users.users.nixery = {
      isNormalUser = false;
      isSystemUser = true;
      description = "Nixery System User";
      group = "nixery";
      extraGroups = [ "nixery" ]; # Optional if you want the user to be in additional groups
      home = "/var/lib/nixery";
    };

    users.groups.nixery = { };
    systemd.services.nixery = {
      description = "Nixery";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "nixery";
        Restart = "always";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.storagePath}";
        ExecStart = "${nixery}/bin/server";
      };

      environment = {
        PORT = cfg.port;
        NIXERY_PKGS_PATH = pkgs.path;
        NIXERY_STORAGE_BACKEND = cfg.storageBackend;
        NIX_TIMEOUT = "60";
        STORAGE_PATH = cfg.storagePath;
        WEB_DIR = "/dev/null";
      };
    };
  };
}
