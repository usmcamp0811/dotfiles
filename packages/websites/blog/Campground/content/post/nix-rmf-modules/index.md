# RMF Compliance on NixOS: A Modern Framework for Secure, Auditable Systems

## Introduction

Achieving compliance with the Risk Management Framework (RMF) has traditionally been a manual and cumbersome
process. System integrators and software vendors must work in lockstep to ensure that supply chain integrity,
auditing, and control enforcement align with NIST 800-53 requirements. This is often hard to scale,
difficult to automate, and resistant to modular reuse.

I present a new framework designed idea for Nix/NixOS that brings modern software engineering practices—declarative
configuration, reproducibility, and immutability—to the RMF compliance process. This model provides a
clean division of responsibilities between software vendors and government integrators.

## Goals

- **Modular Compliance**: Shift RMF enforcement into structured metadata and modular NixOS components
- **Automation**: Enable automated control checks, waivers, and audit logging
- **Reusability**: Support composable and reusable compliance modules across projects

## Core Concepts

The framework defines two primary roles:

### Vendors

Use `wrapWithRMF` to wrap their software packages with RMF metadata and optional install logic. This allows:

- Declaring which RMF controls are "met" or "waived"
- Attaching justifications for waived controls
- Including install modules to automatically configure services
- Exposing configuration options (e.g., port numbers) as `moduleOptions`

### Integrators

Use `mkRmfModuleFromPackage` to consume wrapped packages and:

- Enable/disable the package in system configs
- Selectively enforce or waive controls
- Provide system-specific overrides for settings

## Example Use Case

### Vendor Code

```nix
wrapWithRMF {
  pkg = myApp;
  rmfMeta = {
    approved = false;
    controls = {
      "AC-17" = {
        status = "met";
        config = { networking.firewall.enable = true; };
        srg = [ "SRG-APP-000516" ];
        cci = [ "CCI-000366" ];
      };
      "CM-2" = {
        status = "waived";
        justification = "Manually configured for dev.";
        config = { nix.settings.warn-dirty = true; };
        srg = [ "SRG-APP-000142" ];
        cci = [ "CCI-000366" ];
      };
    };
    poc = "DevSecOps <sec@aicampground.com>";
    lastReviewed = "2025-08-15";
  };
  installModule = { config, pkgs, lib, ... }: {
    config = {
      systemd.services.myApp = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${myApp}/bin/start";
      };
      environment.systemPackages = [ myApp ];
    };
  };
  moduleOptions = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port to run the app.";
    };
  };
}
```

### Integrator Code

```nix
campground.rmf.example-flask-app = {
  enable = true;
  settings = {
    port = 9001;
  };
  controls = {
    CM-2 = {
      enabled = false;
      justification = [ "dev system" ];
    };
  };
};
```

## Built-in Guarantees

- Every control must be marked as `met` or `waived`
- Every waived control must include a `justification`
- Control configs are enforced only if enabled
- Install logic is executed only if the package is enabled

These guarantees ensure that compliance status is declarative and machine-auditable.

## Glossary

| Term            | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| `rmfMeta`       | Metadata declaring RMF control statuses and audit data      |
| `controls`      | Per-control compliance information, configuration, and tags |
| `settings`      | Configurable values surfaced by the vendor                  |
| `installModule` | Optional vendor logic to configure the application          |

## Future Directions

- Add support for STIG profile selection
- Auto-generate OSCAL compliance reports
- Build CI checks for control status validation
- Include SBOM as `passthru` metadata
- Support VM-based penetration testing

## Conclusion

This framework brings reproducibility and modularity to RMF compliance on NixOS. By splitting responsibilities and enforcing structure through type-safe Nix code, it enables secure-by-default patterns that can scale across large, multi-team programs. It sets the foundation for integrating security compliance into the software development lifecycle, rather than treating it as a post-hoc audit artifact.

Learn more or contribute at: [github.com/usmcamp0811/rmf-nix](https://github.com/usmcamp0811/rmf-nix)
