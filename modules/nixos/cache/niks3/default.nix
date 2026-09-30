{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cache.niks3;
in {
  options.fmf.cache.niks3 = with types; {
    enable = mkEnableOption "Campground niks3 binary cache (LAN)";

    url =
      mkOpt str "https://niks3.lan.aicampground.com"
      "URL of the niks3 cache. Reads are served by niks3's read proxy, so this one URL is all clients need.";

    publicKey =
      mkOpt (nullOr str) "reckless-niks3-1:ithnB9sIBPvw6J8XfdTjwLhk7zOQYGhaEXz4ZGfA7oc="
      ''
        Public half of niks3's narinfo signing key (the Vault "sign_key"
        secret), in "name:base64" form. Produce it from the secret key with
        `nix key convert-secret-to-public`. Until this is set the substituter
        is NOT added (Nix would reject every path without a trusted key) and
        a warning is emitted.
      '';
  };

  config = mkIf cfg.enable (mkMerge [
    {
      warnings = optional (cfg.publicKey == null) ''
        fmf.cache.niks3 is enabled but fmf.cache.niks3.publicKey is not set, so
        ${cfg.url} is not being used as a substituter. Set publicKey to the
        public half of niks3's signing key (`nix key convert-secret-to-public`).
      '';
    }

    (mkIf (cfg.publicKey != null) {
      fmf.nix.extra-substituters.${cfg.url}.key = cfg.publicKey;
    })
  ]);
}
