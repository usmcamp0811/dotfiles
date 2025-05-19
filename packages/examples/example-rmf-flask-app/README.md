# RMF Compliance Framework for NixOS

This library provides a clean separation of responsibilities between software **vendors** and **government integrators** for building RMF-compliant systems on NixOS. It enables vendors to declare and enforce supply chain integrity, while giving consumers configurable enforcement and auditing capabilities.

---

## ✨ Overview

The framework is composed of two primary functions:

- `wrapWithRMF`: used by **vendors** to wrap packages with RMF metadata, install modules, and configuration options.
- `mkRmfModuleFromPackage`: used by **government integrators** to enable vendor-wrapped packages, selectively waive controls, and apply vendor install logic.

---

## 🏗️ Vendor Responsibilities

Vendors wrap their Nix packages using `wrapWithRMF`, providing:

- **RMF metadata**: a set of NIST 800-53 controls with `met` or `waived` status.
- **Install module**: NixOS module fragment that installs/configures services.
- **Module options**: Optional knobs exposed for configuration under `settings`.

### Example:

```nix
wrapWithRMF {
  pkg = myApp;

  rmfMeta = {
    approved = false;
    controls = {
      "AC-17" = {
        status = "met";
        config = {
          networking.firewall.enable = true;
        };
        srg = [ "SRG-APP-000516" ];
        cci = [ "CCI-000366" ];
      };
      "CM-2" = {
        status = "waived";
        justification = "Manually configured for dev.";
        config = {
          nix.settings.warn-dirty = true;
        };
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

---

## 🛡️ Integrator Responsibilities

Government consumers use `mkRmfModuleFromPackage` to instantiate a module from the vendor package.

They can:

- Enable/disable the package
- Configure individual RMF controls
- Override settings exposed by the vendor

### Usage in System Configuration:

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

---

## ✅ Assertions Enforced

- Every control must be marked as `met` or `waived`
- Every `waived` control must include a `justification`
- Control configs are only enforced when enabled
- Vendor install logic is only evaluated if the package is enabled

---

## 📚 Glossary

| Term            | Meaning                                                          |
| --------------- | ---------------------------------------------------------------- |
| `rmfMeta`       | Metadata declaring RMF controls and their statuses               |
| `controls`      | The set of security controls tied to RMF requirements            |
| `settings`      | Arbitrary knobs exposed by the vendor via `moduleOptions`        |
| `installModule` | Vendor logic to install and configure the software on the system |

---

## 🛠️ Future Ideas

- Add support for STIG profile selection
- Auto-generate RMF compliance reports from metadata (OSCAL)
- Build CI checks for failed/waived controls
- Include SBOM as `passthru`
- Add options for adding VM pent tests
