{ lib
, config
, pkgs
, ...
}:
with lib; {
  options.campground.services.k3s.modules.argocd.enable = mkEnableOption "Deploy ArgoCD via Helm";

  config = mkIf config.campground.services.k3s.modules.argocd.enable {
    services.k3s.charts.argocd =
      pkgs.runCommand "argocd.tgz"
        {
          nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
        } ''
        cp -r ${pkgs.nixhelmCharts.argoproj.argo-cd} argocd
        tar -czf $out -C argocd .
      '';

    services.k3s.manifests.argocd.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata.name = "argocd";
      spec = {
        chart = "https://%{KUBERNETES_API}%/static/charts/argocd.tgz";
        targetNamespace = "argocd";
        createNamespace = true;
        helmVersion = "v3";
        insecureSkipTLSVerify = true;
      };
    };
  };
}
