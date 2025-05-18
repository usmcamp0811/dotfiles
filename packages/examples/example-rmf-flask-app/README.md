# RMF Compliance Functions for Nix

This module is a proof of concept that provides utility functions to annotate Nix packages with RMF
(Risk Management Framework) metadata and enforce control compliance during evaluation.

---

## 🧩 Functions

### `wrapWithRMF`

Wraps a Nix package with `meta.rmf` fields and asserts that:

- A justification is provided if the package is not approved or any control is unmet.
- `mustMeetControls` is a structured attribute set mapping control IDs to `{ status, justification? }`.

```nix
wrapWithRMF {
  pkg = pkgs.curl;
  rmfMeta = {
    approved = false;
    mustMeetControls = {
      "AC-17" = {
        status = "met";
      };
      "SC-7" = {
        status = "waived";
        justification = "Traffic monitoring handled at the network gateway.";
      };
    };
  };
}
```

---

### `checkRMFCompliance`

Checks whether a package's declared controls are satisfied by the given set of known compliant controls.

```nix
checkRMFCompliance {
  pkg = myWrappedCurl;
  knownCompliantControls = [ "AC-17" "SC-7" ];
}
```

Throws an error if any control with `status = "met"` is not in the known list.

---

### `mkCompliantPackage`

Wraps the package and enforces compliance in a single step. This is the recommended default.

```nix
mkCompliantPackage {
  pkg = pkgs.openssh;
  rmfMeta = {
    approved = false;
    mustMeetControls = {
      "AC-3" = {
        status = "met";
      };
      "CM-2" = {
        status = "waived";
        justification = "Manual config for isolated lab systems.";
      };
    };
    poc = "Security Team <security@example.org>";
    lastReviewed = "2025-08-15";
  };
  knownCompliantControls = [ "AC-3" "CM-2" ];
}
```

---

## ✅ Recommended Usage

Use `mkCompliantPackage` in your flake outputs to enforce compliance at build time:

```nix
outputs = { self, nixpkgs }: {
  packages.x86_64-linux.default =
    let
      rmf = import ./rmf-support.nix { lib = nixpkgs.lib; };
    in
    rmf.mkCompliantPackage {
      pkg = nixpkgs.legacyPackages.x86_64-linux.nginx;
      rmfMeta = {
        approved = false;
        mustMeetControls = {
          "AC-17" = { status = "met"; };
          "SC-7"  = {
            status = "waived";
            justification = "Monitoring handled by WAF.";
          };
        };
        poc = "DevSecOps <devsecops@example.mil>";
        lastReviewed = "2025-08-15";
      };
      knownCompliantControls = [ "AC-17" "SC-7" ];
    };
};
```

---

## 🛡️ Future Improvements

- Enforced status value enums: `met`, `waived`, `deferred`, etc.
- Structured compliance reports (JSON)
- Time-based expiration/`lastReviewed` enforcement
- CI integration for automated policy gatekeeping
