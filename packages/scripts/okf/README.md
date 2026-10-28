# okf

Check, migrate and index [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format)
(OKF) v0.2 bundles: directories of markdown files with YAML frontmatter. How fmf uses
the format is described in `docs/OKF.md`.

```bash
okf check   BUNDLE...            # report violations; exit 1 on errors
okf check   --strict BUNDLE...   # exit 1 on warnings too
okf migrate BUNDLE...            # dry run: files that lack frontmatter
okf migrate --write BUNDLE...    # add frontmatter, index.md files and a log.md entry
okf index   BUNDLE...            # report stale index.md files; exit 1 if any
okf index   --write BUNDLE...    # regenerate them
okf site build --out DIR BUNDLE...   # render a static website (see "site" below)
okf site verify DIR              # check every local link in a built site
```

`--exclude GLOB` (repeatable, bundle-relative) skips paths. `migrate --date YYYY-MM-DD`
sets the `log.md` date.

## check

**Errors** are the spec's conformance rules (§11) and fail the command: a non-reserved
`.md` file needs parseable frontmatter with a non-empty `type`; `index.md` may only have
frontmatter at the bundle root, and only `okf_version`; `log.md` headings must be ISO
dates.

**Warnings** are advice and only fail with `--strict`: malformed optional fields
(`status`, `stale_after`, `generated`, `verified`, `sources`, `usage_window`, timestamps
without a UTC offset, bad actors), a missing `runtime` on an Attested Computation, a
`log.md` that is not newest-first, and broken links. Consumers must tolerate all of these,
so they are never errors. Unknown types and unknown keys are always accepted.

The summary line counts concepts by trust tier (§5.3): unverified, machine-confirmed or
human-reviewed.

## migrate

Adds frontmatter to files that have none and never touches a file that already does. The
body is preserved byte for byte, including CRLF line endings. It derives:

| Key | From |
| --- | --- |
| `type` | The file name and location: `README` beside a `default.nix` is a `NixOS Module` (`Home Manager Module` under `home/`, `Host` under `systems/`); `DESIGN`, `TESTING`, `CHANGELOG` and similar map to their own types; everything else is a `Guide`. |
| `title` | The first `# ` heading, else the file name. |
| `description` | The first prose paragraph, cut to its first sentence. Tables, badges, lists, quotes and "lead-in:" lines are skipped. |
| `resource` | `./default.nix` when a README sits beside one. |
| `tags` | The directory path. |

It **never writes `generated` or `verified`.** OKF derives trust tiers from the `human:`
actor prefix, so stamping files with a review that did not happen would be false. A
missing `verified` honestly means *unverified*. Treat the derived metadata as a first
draft and correct it by hand; running `migrate` again will not overwrite your edits.

With `--write` it also generates the indexes and prepends an entry to `log.md`.

## index

Writes `index.md` files for progressive disclosure: entries grouped by `type`, with each
concept's `description`, then a `Subdirectories` section. The bundle-root index carries
`okf_version: "0.2"`. A directory gets an index if it is the root, has subdirectories, or
holds two or more concepts; a lone concept is linked straight from its parent. Output is
deterministic, so `okf index` doubles as a staleness check.

## site

Renders bundles as a self-contained static website: one page per document, landing and search
pages, and a generated interactive graph page. Resolved Markdown links power the graph and
backlinks; no graph library or server is required. Fonts and all other assets are bundled locally,
so every page works from `file://` and offline.

```bash
okf site build --out ./site --title "Campground" --theme docusaurus --start docs/OKF.md docs modules systems
okf site verify ./site        # every local href, src and form action must exist
```

The site mirrors the bundles' layout (`site/docs/...`, `site/modules/...`), so a relative
link that leaves one bundle for another, such as a host README showing `docs/images/x.jpg`,
keeps working. Bundle directory names must therefore be unique.

- **Links** between documents are rewritten from `.md` to `.html`, and `/path.md`
  bundle-absolute links resolve against the bundle root. A link to something the site does
  not contain (a broken link, or a code file) renders as plain text with a tooltip instead
  of a dead link.
- **Assets:** only images and PDFs a document refers to are copied. A remote image becomes a
  plain link, so a page never loads anything from outside.
- **Each page** shows its frontmatter as a small plate, with a rule down the left edge that
  encodes the trust tier: dotted for unverified, solid for machine-confirmed, heavy for
  human-reviewed. A page past `stale_after` shows a warning (this runs in the browser, so
  the site does not need rebuilding to notice).
- **Search** runs in the browser over title, description, tags, type and body text. It
  understands `type:`, `tag:`, `bundle:` and `trust:` filters. The index is loaded with a
  script tag rather than `fetch`, which is what lets it work from `file://`.
- **Graph and backlinks** are generated from the renderer's already-resolved Markdown links.
  Each concept is a node; valid links between concepts are edges. The graph data is deterministic
  JSON embedded as a local script, and the canvas interaction has a text-list fallback.
- **`okf site build` fails** if the finished site has a broken local reference, and refuses
  to overwrite a non-empty directory that it did not create.

The Nix package also exposes `mkSite`, which builds a site and a launcher script that opens
it:

```nix
pkgs.fmf.okf.mkSite {
  name = "my-docs";
  src = ./.;                          # a tree that contains the bundles
  bundles = ["docs" "modules"];
  title = "My knowledge";
  start = "docs/OKF.md";              # optional: the landing page points here
  theme = "trail-map";                # optional (default navy): navy, navy-light, usmc, docusaurus, field-manual, trail-map, manpage, lantern, toc, okf-visualizer, okf-visualizer-dark
}
```

`campground` (`packages/applications/campground`) is that, applied to this repository:

```bash
nix run .#campground                         # open in the first browser found
nix run .#campground -- --browser qutebrowser
nix run .#campground -- --theme lantern
nix run .#campground -- --search 'vault'
nix run .#campground -- --print              # print the file:// URL only
```

## Tests

```bash
nix build .#checks.x86_64-linux.okf
```

or, while editing:

```bash
cd packages/scripts/okf
nix-shell -p 'python3.withPackages (ps: [ ps.pyyaml ])' --run 'python -m unittest -v'
```
