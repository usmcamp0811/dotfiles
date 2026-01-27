# Default configuration values for all layers
{
  vaultAddress = "http://10.8.0.3:8200";
  vaultKvPath = "secret/campground/k3s";
  vaultKvVersion = "v2";

  metallb = {
    ipPool = {
      name = "default-pool";
      addresses = ["10.8.40.100-10.8.40.255"];
      autoAssign = true;
    };
  };

  argocd = {
    ingressEnabled = false;
    ingressHost = "argocd.k8s.example.com";
    ingressClass = "traefik-k8s";
  };
}
