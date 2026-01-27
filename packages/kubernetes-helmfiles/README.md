# kubernetes-helmfiles

A Nix package that generates Kubernetes helmfile configurations with a layered architecture for deploying baseline cluster infrastructure.

## Overview

This package provides declarative helmfile YAML configurations for deploying essential Kubernetes infrastructure components including external-secrets, cert-manager, Vault integration, MetalLB load balancer, and ArgoCD GitOps.

The package uses a layered approach that mirrors the deployment order:

- **Layer 00**: CRDs (Custom Resource Definitions)
- **Layer 10**: Controllers (cert-manager)
- **Layer 20**: Secrets (Vault Kubernetes auth, ClusterSecretStore)
- **Layer 30**: Networking (MetalLB load balancer)
- **Layer 60**: GitOps (ArgoCD)

## Building

```bash
# Build the package
cd /config
nix build .#kubernetes-helmfiles

# Inspect the output
ls -la result/
cat result/helmfile.yaml
cat result/layers/20-secrets.yaml
```

## Package Outputs

After building, the package provides:

```
result/
├── helmfile.yaml           # Complete helmfile with all layers merged
├── repositories.yaml       # Helm repository configurations
└── layers/
    ├── 00-crds.yaml       # External Secrets CRDs
    ├── 10-controllers.yaml # cert-manager controller
    ├── 20-secrets.yaml    # Vault auth + ClusterSecretStore
    ├── 30-networking.yaml # MetalLB configuration
    └── 60-gitops.yaml     # ArgoCD deployment
```

## Default Configuration

### Vault Settings

```nix
{
  vaultAddress = "http://192.168.0.3:8200";
  vaultKvPath = "secret/campground/k3s";
  vaultKvVersion = "v2";
}
```

### MetalLB Settings

```nix
{
  metallb.ipPool = {
    name = "default-pool";
    addresses = ["10.8.40.100-10.8.40.255"];
    autoAssign = true;
  };
}
```

### ArgoCD Settings

```nix
{
  # Default: ClusterIP service, no ingress
  # Can be overridden via mkBaseline or mkGitopsReleases
}
```

## Customization

The package exposes several functions via `passthru` for customization:

### Custom Baseline Helmfile

Create a complete helmfile with custom configuration:

```nix
pkgs.fmf.kubernetes-helmfiles.mkBaseline {
  # Vault configuration
  vaultAddress = "http://192.168.0.3:8200";
  vaultKvPath = "secret/production/k8s";
  vaultKvVersion = "v2";

  # MetalLB configuration
  metallb = {
    ipPool = {
      name = "prod-pool";
      addresses = ["192.168.1.100-192.168.1.200"];
      autoAssign = true;
    };
  };

  # ArgoCD ingress
  argocdIngressEnabled = true;
  argocdIngressHost = "argocd.k8s.example.com";
  argocdIngressClass = "traefik-k8s";
}
```

### Custom Secrets Layer

Generate just the secrets layer with different Vault settings:

```nix
pkgs.fmf.kubernetes-helmfiles.mkSecretsReleases {
  vaultAddress = "https://vault.prod.example.com:8200";
  vaultKvPath = "secret/k8s/prod";
  vaultKvVersion = "v2";
}
```

### Custom Networking Layer

Generate MetalLB configuration with different IP pools:

```nix
pkgs.fmf.kubernetes-helmfiles.mkNetworkingReleases {
  metallb.ipPool = {
    name = "external-pool";
    addresses = [
      "10.0.100.1-10.0.100.50"
      "10.0.200.1-10.0.200.50"
    ];
    autoAssign = false;
  };
}
```

### Custom GitOps Layer

Configure ArgoCD with or without ingress:

```nix
# Without ingress (default)
pkgs.fmf.kubernetes-helmfiles.mkGitopsReleases {}

# With ingress
pkgs.fmf.kubernetes-helmfiles.mkGitopsReleases {
  argocdIngressEnabled = true;
  argocdIngressHost = "argocd.example.com";
  argocdIngressClass = "nginx";
}
```

## Passthru Attributes

Access individual components programmatically:

```nix
# Individual layer YAML files
pkgs.fmf.kubernetes-helmfiles.layers.crds
pkgs.fmf.kubernetes-helmfiles.layers.controllers
pkgs.fmf.kubernetes-helmfiles.layers.secrets
pkgs.fmf.kubernetes-helmfiles.layers.networking
pkgs.fmf.kubernetes-helmfiles.layers.gitops

# Raw release data (Nix values before YAML conversion)
pkgs.fmf.kubernetes-helmfiles.releases.crds
pkgs.fmf.kubernetes-helmfiles.releases.controllers
# ... etc

# Functions
pkgs.fmf.kubernetes-helmfiles.mkSecretsReleases
pkgs.fmf.kubernetes-helmfiles.mkNetworkingReleases
pkgs.fmf.kubernetes-helmfiles.mkGitopsReleases
pkgs.fmf.kubernetes-helmfiles.mkBaseline

# Default baseline and repositories
pkgs.fmf.kubernetes-helmfiles.baseline
pkgs.fmf.kubernetes-helmfiles.repositories
pkgs.fmf.kubernetes-helmfiles.repositoriesList

# Convenience YAML accessors
pkgs.fmf.kubernetes-helmfiles.yaml.baseline
pkgs.fmf.kubernetes-helmfiles.yaml.secrets
# ... etc
```

## Usage in NixOS Modules

Example of how to use this package in a NixOS configuration:

```nix
{ pkgs, config, ... }:
{
  # Generate custom helmfile
  environment.etc."helmfile/helmfile.yaml".source =
    pkgs.fmf.kubernetes-helmfiles.mkBaseline {
      vaultAddress = config.services.vault.address;
      metallb.ipPool.addresses = ["10.8.40.100-10.8.40.255"];
      argocdIngressEnabled = true;
      argocdIngressHost = "argocd.${config.networking.domain}";
    };

  # Or use individual layers
  environment.etc."helmfile/layers/20-secrets.yaml".source =
    pkgs.fmf.kubernetes-helmfiles.layers.secrets;
}
```

## Testing

Build and inspect a custom configuration:

```bash
# Build with custom settings
nix build --impure --expr '
  with import <nixpkgs> {};
  (callPackage ./packages/kubernetes-helmfiles/default.nix {}).passthru.mkBaseline {
    vaultAddress = "http://vault.test:8200";
    argocdIngressEnabled = true;
    argocdIngressHost = "argocd.test.local";
  }
'

# View the generated helmfile
cat result

# Validate with helmfile (if available)
helmfile -f result template
```

## Architecture

### Layer Dependencies

```
60-gitops (ArgoCD)
    ├─ depends on: external-secrets, metallb, cert-manager
    └─ enables: 50-ingress, 40-storage, 20-secrets

30-networking (MetalLB)
    └─ depends on: external-secrets

20-secrets (Vault + ClusterSecretStore)
    ├─ depends on: external-secrets
    └─ enables: 10-controllers, 00-crds

10-controllers (cert-manager)
    └─ enables: 00-crds

00-crds (External Secrets)
    └─ base layer
```

### Helm Repositories

The package includes configuration for these Helm repositories:

- **external-secrets**: https://charts.external-secrets.io
- **jetstack**: https://charts.jetstack.io (cert-manager)
- **dysnix**: https://dysnix.github.io/charts (raw manifests)
- **metallb**: https://metallb.github.io/metallb
- **argo**: https://argoproj.github.io/argo-helm

## Workarounds

The package includes several workarounds for known cluster issues:

### Webhook Validation Workarounds

Due to Service VIP routing issues, ValidatingWebhookConfigurations are deleted:

- **cert-manager**: `startupapicheck` disabled
- **external-secrets**: `secretstore-validate` webhook deleted via presync hook
- **MetalLB**: `metallb-webhook-configuration` deleted via postsync hook

### MetalLB Configuration

MetalLB configuration is applied via a postsync hook rather than separate manifests to ensure proper ordering after webhook deletion.

## Development

### File Structure

```
kubernetes-helmfiles/
├── default.nix          # Main package definition
└── README.md           # This file
```

### Adding New Layers

To add a new layer:

1. Define the releases as a Nix list or function
2. Generate the YAML layer file using `yamlFormat.generate`
3. Add to the `mkBaseline` function's release concatenation
4. Expose via `passthru.layers` and `passthru.releases`
5. Update layer number appropriately (e.g., 40, 50, etc.)

Example:

```nix
# Define releases
storageReleases = [ /* ... */ ];

# Generate YAML
storageLayer = yamlFormat.generate "40-storage.yaml" {
  releases = map addCreateNamespace storageReleases;
};

# Add to mkBaseline
allReleases = map addCreateNamespace (
  crdsReleases
  ++ controllersReleases
  ++ secretsReleases
  ++ networkingReleases
  ++ storageReleases  # Add here
  ++ gitopsReleases
);

# Expose via passthru
passthru = {
  layers = {
    # ...
    storage = storageLayer;
  };
  releases = {
    # ...
    storage = storageReleases;
  };
};
```

## Related Documentation

- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [External Secrets Operator](https://external-secrets.io/)
- [cert-manager](https://cert-manager.io/)
- [MetalLB](https://metallb.universe.tf/)
- [ArgoCD](https://argo-cd.readthedocs.io/)

## Troubleshooting

### YAML Formatting Issues

The package uses `pkgs.formats.yaml` to ensure proper YAML output. If you see JSON-like output instead of YAML, verify you're using `yamlFormat.generate` and not `builtins.toJSON`.

### Missing createNamespace

All releases should have `createNamespace = true`. This is added via the `addCreateNamespace` helper function. If missing, check that `map addCreateNamespace` is being used.

### Dependency Issues

Helmfile uses the `needs` field (not `dependsOn`) for release dependencies. The package correctly maps `dependsOn` from NixOS modules to `needs` in the helmfile format.

### Function Evaluation Errors

When using `mkBaseline` or other functions, ensure all required parameters are provided or have defaults. Use `nix eval` with `--show-trace` for detailed error messages.

## License

Part of the Campground NixOS infrastructure configuration.
