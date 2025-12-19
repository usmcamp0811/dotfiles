{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli.k9s;
in
{
  options.fmf.cli.k9s = with types; {
    enable = mkBoolOpt false "Whether or not to enable K9s.";
  };

  config = mkIf cfg.enable {
    fmf.cli.aliases = {
      k = ''
        ${pkgs.kubectl}/bin/kubectl $@
      '';
      kwatch = ''
        watch ${pkgs.kubectl}/bin/kubectl $@
      '';
      get-kconfig = ''
        ${pkgs.vault-bin}/bin/vault kv get -field=kubeconfig "secret/campground/k3s" > "KUBECONFIG"
      '';
    };
    home.packages = with pkgs; [ k9s kubernetes-helm kubectl ];
  };
}
