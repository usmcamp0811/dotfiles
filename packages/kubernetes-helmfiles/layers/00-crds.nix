# Layer 00: CRDs (Custom Resource Definitions)
# External Secrets Operator CRDs
{...}: [
  {
    name = "external-secrets";
    namespace = "external-secrets";
    chart = "external-secrets/external-secrets";
    wait = true;
    timeout = 300;
  }
]
