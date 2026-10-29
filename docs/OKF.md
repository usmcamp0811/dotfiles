---
type: Guide
title: Open Knowledge Format in fmf
description: How fmf's docs, modules and systems directories are OKF v0.2 bundles, and how to keep them conformant.
tags: [okf, docs]
---

# Open Knowledge Format in fmf

fmf's written knowledge follows the [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format)
(OKF) v0.2: markdown files with YAML frontmatter, organised as **bundles**. A person
can read them with `cat`, an agent can load them without a custom SDK, and they diff
cleanly in git. Start at a bundle's `index.md` and follow the links down.

## Bundles

A bundle is a directory. These three are bundles **in place**: nothing was moved, so a
module's README still sits next to its `default.nix`.

| Bundle | Holds | Entry point |
| --- | --- | --- |
| [`docs/`](./index.md) | Guides, runbooks, references and notes | `docs/index.md` |
| `modules/` | One README per module, plus design, testing and changelog files | `modules/index.md` |
| `systems/` | One README per host, plus host runbooks | `systems/index.md` |

Not bundles yet: `packages/` (third-party and generated markdown mixed in), the repo-root
README and `CLAUDE.md`, and the downstream Campground repository.

## Anatomy of a concept

Every markdown file other than `index.md` and `log.md` is a **concept**. The only required
frontmatter key is `type`; the rest is what fmf uses by convention:

```markdown
---
type: NixOS Module
title: Nostalgex web tuner (fmf.services.nostalgex)
description: Serves the Nostalgex web tuner, a retro cable-TV channel guide, with Nginx.
resource: ./default.nix
tags: [services, nostalgex]
---

# Nostalgex web tuner
...
```

| Key | Meaning |
| --- | --- |
| `type` | Required. What kind of document this is (below). |
| `title` | Display name. Defaults to the first heading. |
| `description` | One sentence. It is copied into the parent `index.md`, so write it for someone deciding whether to open the file. |
| `resource` | The asset the document describes. For a module or host README this is the sibling `./default.nix`. |
| `tags` | Cross-cutting labels. Derived from the directory path. |

### Types in use

`NixOS Module`, `Home Manager Module` and `Host` describe code that sits beside the
file. `Overview`, `Design`, `Architecture`, `Guide`, `Reference`, `Runbook`,
`Troubleshooting`, `Test Guide`, `Examples`, `Tutorial`, `Changelog`, `Todo` and `Note`
describe everything else. OKF does not register types: pick the one that fits, and a new
one is fine.

## Trust: do not claim a review that did not happen

OKF has optional `generated`, `verified`, `status`, `stale_after` and `sources` fields.
Consumers derive a **trust tier** from them: no `verified` is *unverified*, a `verified`
by a `process:` or agent actor is *machine-confirmed*, and any `human:<id>` makes it
*human-reviewed*.

The migration that created these bundles added none of those fields, so every existing
document is honestly *unverified*. Add them only when true:

```yaml
generated: { by: my-agent/1.0, at: 2026-10-19T14:00:00Z }     # <producer>/<version>
verified: { by: human:mcamp, at: 2026-10-19T15:30:00Z }   # only after you actually reviewed it
status: draft                  # draft | stable | deprecated; absent means stable
stale_after: 2027-04-19T00:00:00Z
```

Timestamps are ISO 8601 with an explicit UTC offset. Actors are `<producer>/<version>`,
`human:<id>` or `process:<id>`.

## Working with bundles

The `okf` tool (`packages/scripts/okf`) checks, migrates and indexes bundles:

```bash
nix run .#okf -- check docs modules systems            # errors fail, warnings are advice
nix run .#okf -- check --strict docs modules systems   # warnings fail too
nix run .#okf -- migrate docs                          # dry run: files that lack frontmatter
nix run .#okf -- migrate --write docs                  # add frontmatter, indexes and log.md
nix run .#okf -- index --write docs modules systems    # regenerate index.md files
```

`nix build .#checks.x86_64-linux.okf` runs the tool's tests and fails if a bundle has an
error or a stale index, if the website below has a broken link, or if any page loads
something from outside the site.

## Reading them in a browser

### Generated module options

The **options** bundle is generated during `nix build .#campground` using
`pkgs.nixosOptionsDoc` and a documentation-only NixOS evaluation. It lists public
`fmf.*` option names, types, descriptions and defining modules, grouped by namespace,
with links to authored module guides where available. Search with `bundle:options`.
Generated pages are not committed and are rebuilt automatically by Pages CI.

This is a schema reference, not a real host evaluation: defaults and examples are
omitted because some module defaults require host-specific or Vault configuration.
The unfinished `rmf/example-flask-app` module is excluded because it redeclares
`fmf.controls` and cannot be evaluated alongside the real RMF module. No secret or
dummy host values are supplied, and no review/trust claims are generated.

### Authored bundles

`campground` renders the authored bundles and generated options as a static website:
one page per document, a persistent section sidebar and top navigation, an outline, backlinks,
a local graph on concept pages, search, and a global graph of document links. The dark Navy Mk II
theme is the default; its light variant is available from the header toggle. Nothing is fetched
from the internet at view time, so it works offline straight from the Nix store. By default
nothing is served either; `--serve` is there for reading it from another machine.

```bash
nix run .#campground                                  # open it in the first browser found
nix run .#campground -- --browser qutebrowser         # or pick one (arguments are allowed)
nix run .#campground -- --search 'vault tag:services' # open the search page for a query
nix run .#campground -- --theme navy-mk2-light             # use a theme for this visit
nix run .#campground -- modules/nixos/services/niks3/README.html
nix run .#campground -- --print                       # print the file:// URL, open nothing
nix run .#campground -- --serve --bind 0.0.0.0 --port 8080   # serve it to the network
```

`--serve` serves the same files over HTTP instead of opening a browser (127.0.0.1:8080 unless
`--bind` and `--port` say otherwise). It is a plain static file server with no
authentication, so bind `0.0.0.0` only on a network you trust.

The browser is the first of `--browser`, `$OKF_BROWSER`, `$BROWSER`, then `qutebrowser`,
`firefox`, `brave`, `chromium`, `google-chrome-stable` and `xdg-open`.

Search matches every word, and narrows with `type:Guide`, `tag:vault`, `bundle:modules` or
`trust:unverified`. Quote multi-word values: `type:"NixOS Module"`. Press `/` on any page
to jump to the search box.

**The rule down the left edge of a page is its trust level**: dotted means unverified,
solid olive means machine-confirmed, and a heavy brass line means human-reviewed. Today
every page is dotted, because nothing has been reviewed yet. A page whose `stale_after` has
passed also shows a warning.

The footer theme picker remembers your choice in that browser. There are two themes, **Navy Mk II**
(the default; dark blue, blue links and a one-row header) and **Navy Mk II Light**, and the header
toggle flips between them. The selected theme follows internal links and
search results, including when the site is opened from `file://`. The launcher can select one
for a visit with `--theme`; it does not need a rebuild. The graph is built from resolved Markdown
links: each concept is a node, each valid link between concepts is an edge, and the same links
generate the page backlinks. Global and local graphs and the text link list are all static output;
no graph service or client-side CDN is involved.

Authored pages are built from Markdown and images; the options reference is generated
from module schemas. Links to code files (for example `default.nix`) show as plain text,
since the site does not contain them.

A downstream flake can publish its own bundles the same way:

```nix
pkgs.fmf.okf.mkSite {
  name = "campground-docs";
  src = ./.;                       # a tree that contains the bundles
  bundles = ["docs" "systems"];
  title = "Campground";
  theme = "navy-mk2-light";
}
```

- **New document:** write the frontmatter yourself (`type` at minimum), then run
  `okf index --write <bundle>` so the parent index lists it.
- **Changed `title` or `description`:** run `okf index --write <bundle>` again; the check
  fails until you do.
- **Indexes are generated.** Do not edit `index.md` by hand. A directory gets one if it
  is the bundle root, has subdirectories, or holds two or more concepts; a lone concept is
  linked from its parent.
- **`log.md`** at the bundle root is hand-kept history, newest first, with `## YYYY-MM-DD`
  headings.
- **Links** are ordinary markdown links, preferably bundle-relative (`/modules/...`) or
  relative. A broken link is a warning, not an error, because OKF allows links to
  knowledge that is not written yet.

## Known gaps

- `docs/VIDEO-LOCK-SCREEN-FMF.md` links to `/docs/VIDEO-LOCK-SCREEN.md`, which exists in
  the Campground repository, not here. `okf check` reports it.
- Descriptions were derived from each file's first paragraph and hand-corrected where that
  was wrong. Some will still be weaker than a sentence you would write; improve them in
  place and regenerate the index.
