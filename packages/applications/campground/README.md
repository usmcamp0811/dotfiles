---
type: Package
title: Campground documentation site
description: Build and browse the flake's authored documentation and generated NixOS options reference as an offline static site.
tags: [documentation, okf, nixos]
---

# Campground documentation site

## Browse locally

Run these commands from the flake root:

```bash
nix run .#campground
nix run .#campground -- --theme navy-mk2-light
nix run .#campground -- --search 'bundle:options immich'
nix run .#campground -- --browser firefox options/index.html
nix run .#campground -- --print
nix run .#campground -- --serve --bind 0.0.0.0 --port 8080
```

By default the launcher opens local HTML from the Nix store; no web server is required.
`--serve` instead serves it over HTTP (`--bind` defaults to 127.0.0.1, `--port` to 8080)
and opens no browser; it has no authentication, so use `0.0.0.0` only on a trusted network.
`--print` prints the URL without opening a browser or serving. Use `--browser`, `OKF_BROWSER`,
or `BROWSER` to select a browser, or let the launcher choose an installed one.

The default is the dark Navy Mk II theme. The header button switches between dark and light, and
the footer picker does the same. Theme choice follows internal links and search submissions,
including under
`file://`.

## Content

| Section | Source |
| --- | --- |
| `docs` | Guides and runbooks in `docs/` |
| `modules` | Authored module documentation in `modules/` |
| `systems` | Host documentation in `systems/` |
| `options` | Build-generated reference for public `fmf.*` NixOS options |

The site includes local search, page outlines, generated backlinks, global and per-document
interactive knowledge graphs, trust metadata, syntax highlighting, and Mermaid rendering from a
pinned local asset. The graph is generated from existing Markdown links and runs entirely in the
browser with no graph library or backend. Viewing the built
site requires no CDN or network access. Building it may fetch Nix inputs and
dependencies.

### Generated options reference

`options.nix` performs a documentation-only NixOS evaluation and uses
`pkgs.nixosOptionsDoc` to extract option schemas. `options.py` groups that JSON into
OKF Markdown pages and links to authored module guides where available. Generated
pages are build outputs, not checked-in documentation.

The reference contains option names, types, descriptions, and declaration paths.
It is **not** a host's effective configuration:

- Defaults and examples are omitted because some require host-specific or Vault
  settings; no dummy secret values are supplied.
- Only the public `fmf.*` options are included, not the entire upstream NixOS manual.
- The unfinished `rmf/example-flask-app` module is excluded because it redeclares
  an option owned by the RMF module.
- Missing descriptions remain identified as missing; generation does not imply
  human review.

## Build and verify

```bash
nix build .#campground
nix build .#checks.x86_64-linux.okf --no-link
```

The built website is in `result/share/campground/`. The OKF check runs the tool and
options-converter tests, validates the authored bundles and generated indexes,
checks local site references, and exercises launcher URL handling.

For authored-document conventions and index maintenance, see
[Open Knowledge Format in fmf](../../../docs/OKF.md). The reusable renderer and
launcher are documented in [the OKF tool README](../../scripts/okf/README.md).

## Publishing

[Campground on GitLab Pages](https://usmcamp0811.gitlab.io/dotfiles/campground/)
is built by the repository's GitLab CI configuration. The default-branch Pages
artifact contains the site under `public/campground/` alongside the existing
`public/domainswild` blocklist.
