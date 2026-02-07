{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.brave;

  # Fetch bypass-paywalls extension from GitHub
  bypass-paywalls-extension = pkgs.stdenv.mkDerivation {
    pname = "bypass-paywalls-chrome-clean";
    version = "latest";

    src = pkgs.fetchFromGitHub {
      owner = "fortarch";
      repo = "bypass-paywalls-chrome-clean-magnolia1234-kiwibrowser";
      rev = "master";
      sha256 = "sha256-1usZeyQhL3vGXoCj5aRKuwyJ4W2TeDWzcXOnFGTbpZU=";
    };

    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };
in
{
  options.fmf.apps.brave = with types; {
    enable = mkBoolOpt false "Whether or not to enable Brave.";
    cac = mkBoolOpt false "Enable CAC Support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ nssTools pkcs11helper ];

    fmf.home.extraOptions = {
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        extensions = [
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
          { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
          { id = "iaddfgegjgjelgkanamleadckkpnjpjc"; } # Auto Quality for YouTube
          { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
          { id = "annfbnbieaamhaimclajlajpijgkdblo"; } # Dark Theme
        ];
      };

      # Install bypass-paywalls extension unpacked
      home.file.".config/BraveSoftware/Brave-Browser/Extensions/bypass-paywalls" = {
        source = bypass-paywalls-extension;
        recursive = true;
      };
    };
    # systemd.services.installCACerts = {
    #   description = "Install CAC certificates into Chromium based Browsers";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = "yes";
    #     ExecStart = "${installCACertsScript}";
    #   };
    # };

    fmf.services.cac.enable = mkIf cfg.cac true;
  };
}
