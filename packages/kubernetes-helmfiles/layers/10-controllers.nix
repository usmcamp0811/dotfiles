# Layer 10: Controllers
# cert-manager controller with CRDs
{...}: [
  {
    name = "cert-manager";
    namespace = "cert-manager";
    chart = "jetstack/cert-manager";
    wait = true;
    timeout = 600;
    set = [
      {
        name = "installCRDs";
        value = "true";
      }
      {
        name = "startupapicheck.enabled";
        value = "false";
      }
    ];
  }
]
