"""okf_site: render OKF bundles as a self-contained static website.

No CDN, no fonts, no server: every page works from file:// and offline. The
site mirrors the layout of the bundles, so relative links between bundles (for
example a host README pointing at ../../../docs/images/x.jpg) keep working.

Used through `okf site build` (see okf.py).
"""
from __future__ import annotations

import html
import json
import os
import re
import shutil
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote

from markdown_it import MarkdownIt
from mdit_py_plugins.anchors import anchors_plugin
from mdit_py_plugins.footnote import footnote_plugin
from pygments import highlight as pyg_highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from pygments.util import ClassNotFound

import okf

ASSETS = Path(__file__).resolve().parent / "site"
MARKER = ".okf-site"
SPEC_URL = "https://github.com/GoogleCloudPlatform/open-knowledge-format"
TIER_LABEL = {
    "unverified": "Unverified",
    "machine-confirmed": "Machine-confirmed",
    "human-reviewed": "Human-reviewed",
}
# The themes live in site/style.css as sets of CSS variables; this is the registry
# the build, the footer picker and the launcher agree on. The first is the default.
THEMES = {
    "field-manual": "Field manual",
    "trail-map": "Trail map",
    "manpage": "Man page",
    "lantern": "Lantern",
    "toc": "TOC",
    "okf-visualizer": "OKF Visualizer",
    "okf-visualizer-dark": "OKF Visualizer Dark",
}
DEFAULT_THEME = next(iter(THEMES))
SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")
# Only files a browser can show are copied into the site. Anything else a
# document links to (a .nix file, a script) renders as plain text, so a build
# does not depend on which other files happen to sit beside the markdown.
ASSET_TYPES = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".pdf"}


def esc(text) -> str:
    return html.escape(str(text), quote=True)


def relurl(src: PurePosixPath, dst: PurePosixPath) -> str:
    start = src.parent.as_posix() or "."
    return quote(PurePosixPath(os.path.relpath(dst.as_posix(), start)).as_posix())


def search_href(up: str, query: str) -> str:
    return f"{up}search.html?q={quote(query)}"


# ── Markdown ─────────────────────────────────────────────────────────────────


def _highlight(code: str, lang: str, attrs) -> str:
    name = (lang or "").split()[0].lower() if lang else ""
    if not name:
        return ""
    try:
        lexer = get_lexer_by_name(name)
    except ClassNotFound:
        return ""
    return pyg_highlight(code, lexer, HtmlFormatter(nowrap=True))


def make_markdown() -> MarkdownIt:
    md = MarkdownIt("commonmark", {"highlight": _highlight}).enable(["table", "strikethrough"])
    md.use(footnote_plugin)
    md.use(anchors_plugin, min_level=1, max_level=4)
    return md


# ── Model ────────────────────────────────────────────────────────────────────


@dataclass
class Page:
    bundle: str
    rel: PurePosixPath
    kind: str  # concept | index | log
    src: str
    meta: dict
    body: str
    title: str
    description: str
    type: str
    tier: str | None
    out: PurePosixPath
    env: dict = field(default_factory=dict)
    tokens: list = field(default_factory=list)
    toc: list = field(default_factory=list)  # (level, id, text)
    links_to: set = field(default_factory=set)  # out paths of linked pages
    text: str = ""


def _plain(tokens) -> str:
    parts = []
    for token in tokens:
        if token.type in ("fence", "code_block"):
            parts.append(token.content)
        elif token.type == "inline":
            parts.append(okf.strip_inline(token.content))  # no link or emphasis syntax in snippets
    return re.sub(r"\s+", " ", " ".join(parts)).strip()


class Site:
    def __init__(
        self,
        bundles: list[Path],
        title: str,
        subtitle: str,
        exclude: tuple[str, ...] = (),
        start: str | None = None,
        theme: str = DEFAULT_THEME,
        mermaid: str | None = None,
    ):
        if theme not in THEMES:
            raise ValueError(f"unknown theme {theme!r}; choose from {', '.join(THEMES)}")
        self.theme = theme
        self.mermaid = mermaid
        self.title = title
        self.subtitle = subtitle
        self.start = start  # e.g. "docs/OKF.md": a page the landing page points new readers to
        self.roots: dict[str, str] = {}
        for bundle in bundles:
            root = os.path.normpath(Path(bundle).absolute())
            name = os.path.basename(root)
            if name in self.roots:
                raise ValueError(f"two bundles are called {name!r}; bundle directory names must be unique")
            self.roots[name] = root
        self.md = make_markdown()
        self.pages: list[Page] = []
        self.by_src: dict[str, Page] = {}
        self.assets: dict[PurePosixPath, str] = {}
        self.backlinks: dict[PurePosixPath, list[Page]] = {}
        self._load(exclude)
        for page in self.pages:
            self._prepare(page)
        for page in self.pages:
            if page.kind != "concept":
                continue
            for target in page.links_to:
                self.backlinks.setdefault(target, []).append(page)

    # loading ---------------------------------------------------------------

    def _load(self, exclude) -> None:
        for name, root in self.roots.items():
            for path in okf.iter_markdown(Path(root), exclude):
                rel = PurePosixPath(path.relative_to(root).as_posix())
                text = path.read_text(encoding="utf-8")
                try:
                    raw, body = okf.split_frontmatter(text)
                    meta = okf.load_meta(raw) if raw is not None else {}
                except ValueError:
                    meta, body = {}, text
                if path.name == "index.md":
                    kind, title = "index", "/".join([name, *rel.parent.parts])
                    type_, tier = "Index", None
                elif path.name == "log.md":
                    kind, title = "log", "Update log"
                    type_, tier = "Log", None
                else:
                    kind = "concept"
                    title = str(meta.get("title") or okf.derive_title(body, path))
                    type_ = str(meta.get("type") or "Concept")
                    tier = okf.trust_tier(meta)
                page = Page(
                    bundle=name,
                    rel=rel,
                    kind=kind,
                    src=os.path.normpath(path.absolute()),
                    meta=meta,
                    body=body,
                    title=title,
                    description=" ".join(str(meta.get("description") or "").split()),
                    type=type_,
                    tier=tier,
                    out=PurePosixPath(name) / rel.with_suffix(".html"),
                )
                self.pages.append(page)
                self.by_src[page.src] = page
        self._synthesize_indexes()

    def _synthesize_indexes(self) -> None:
        """A bundle need not have run `okf index --write`: any index page the site
        would link to but the bundle lacks is generated with the same rules."""
        for name, root in self.roots.items():
            concepts = [
                okf.Concept(p.rel, p.type, p.title, p.description)
                for p in self.pages
                if p.bundle == name and p.kind == "concept"
            ]
            directories = {PurePosixPath(".")}
            for concept in concepts:
                directories.update(concept.rel.parents)
            for directory in sorted(directories):
                rel = directory / "index.md"
                src = os.path.normpath(os.path.join(root, rel.as_posix()))
                if src in self.by_src or not okf.wants_index(concepts, directory):
                    continue
                _, body = okf.split_frontmatter(okf.render_index(concepts, directory))
                page = Page(
                    bundle=name,
                    rel=rel,
                    kind="index",
                    src=src,
                    meta={},
                    body=body,
                    title="/".join([name, *directory.parts]) if directory.parts else name,
                    description="",
                    type="Index",
                    tier=None,
                    out=PurePosixPath(name) / rel.with_suffix(".html"),
                )
                self.pages.append(page)
                self.by_src[src] = page

    # link resolution -------------------------------------------------------

    def _resolve(self, page: Page, bare: str):
        """('page', Page) | ('asset', site path, source) | None."""
        base = self.roots[page.bundle] if bare.startswith("/") else os.path.dirname(page.src)
        target = os.path.normpath(os.path.join(base, bare.lstrip("/") if bare.startswith("/") else bare))
        if target in self.by_src:
            return "page", self.by_src[target]
        index = os.path.join(target, "index.md")
        if os.path.isdir(target) and index in self.by_src:
            return "page", self.by_src[index]
        if os.path.isfile(target) and os.path.splitext(target)[1].lower() in ASSET_TYPES:
            for name, root in self.roots.items():
                if target.startswith(root + os.sep):
                    rel = PurePosixPath(os.path.relpath(target, root).replace(os.sep, "/"))
                    return "asset", PurePosixPath(name) / rel, target
        return None

    def _rewrite_link(self, page: Page, href: str):
        """Return (new href or None, extra attrs). None means unresolvable."""
        if href.startswith("#"):
            return href, {}
        if SCHEME.match(href) or href.startswith("//"):
            return href, {"class": "external", "rel": "noopener"}
        path, _, fragment = href.partition("#")
        bare = unquote(re.split(r"[?]", path, maxsplit=1)[0])
        if not bare:
            return None, {}
        found = self._resolve(page, bare)
        if not found:
            return None, {}
        suffix = f"#{fragment}" if fragment else ""
        if found[0] == "page":
            if found[1].out != page.out:
                page.links_to.add(found[1].out)
            return relurl(page.out, found[1].out) + suffix, {}
        _, site_path, source = found
        self.assets[site_path] = source
        return relurl(page.out, site_path) + suffix, {}

    def _rewrite_inline(self, page: Page, children) -> None:
        close_as_span = False
        for child in children:
            if child.type == "link_open":
                href = child.attrGet("href") or ""
                new, attrs = self._rewrite_link(page, href)
                if new is None:
                    child.tag = "span"
                    child.attrs = {"class": "unresolved", "title": f"{href} is not part of this site"}
                    close_as_span = True
                else:
                    child.attrSet("href", new)
                    for key, value in attrs.items():
                        child.attrSet(key, value)
            elif child.type == "link_close" and close_as_span:
                child.tag = "span"
                close_as_span = False
            elif child.type == "image":
                src = child.attrGet("src") or ""
                alt = child.content or ""
                if SCHEME.match(src) or src.startswith("//"):
                    child.type, child.tag, child.children = "html_inline", "", None
                    child.content = f'<a class="remote-image" href="{esc(src)}">{esc(alt or src)}</a>'
                    continue
                new, _ = self._rewrite_link(page, src)
                if new is None:
                    child.type, child.tag, child.children = "html_inline", "", None
                    child.content = f'<span class="unresolved">{esc(alt)}</span>'
                else:
                    child.attrSet("src", new)

    def _prepare(self, page: Page) -> None:
        tokens = self.md.parse(page.body, page.env)
        for i, token in enumerate(tokens):
            if token.type == "heading_open":
                level = int(token.tag[1])
                if page.kind == "index":
                    token.tag = f"h{min(level + 1, 6)}"
                inline = tokens[i + 1] if i + 1 < len(tokens) else None
                ident = token.attrGet("id")
                if inline is not None and ident and 2 <= level <= 3 and page.kind != "index":
                    page.toc.append((level, ident, okf.strip_inline(inline.content)))
            elif token.type == "heading_close" and page.kind == "index":
                token.tag = f"h{min(int(token.tag[1]) + 1, 6)}"
            if token.type == "inline" and token.children:
                self._rewrite_inline(page, token.children)
        page.tokens = tokens
        page.text = _plain(tokens)[:20000]

    # rendering -------------------------------------------------------------

    def render_body(self, page: Page) -> tuple[str, str]:
        """Return (heading html, body html); a lone H1 becomes the page heading."""
        tokens = page.tokens
        lead = ""
        if page.kind != "index" and tokens[:1] and tokens[0].type == "heading_open" and tokens[0].tag == "h1":
            lead = self.md.renderer.render(tokens[:3], self.md.options, page.env)
            tokens = tokens[3:]
        else:
            lead = f"<h1>{esc(page.title)}</h1>\n"
        return lead, self.md.renderer.render(tokens, self.md.options, page.env)

    def _tree(self, current: Page) -> str:
        members = [p for p in self.pages if p.bundle == current.bundle]
        root: dict = {"dirs": {}, "files": []}
        for page in members:
            node = root
            for part in page.rel.parts[:-1]:
                node = node["dirs"].setdefault(part, {"dirs": {}, "files": []})
            node["files"].append(page)
        ancestors = set(current.rel.parents)

        def marker(page: Page) -> str:
            return f'<span class="mark tier-{page.tier}" aria-hidden="true"></span>' if page.tier else ""

        def render(node: dict, prefix: PurePosixPath) -> str:
            lines = ["<ul>"]
            files = sorted(node["files"], key=lambda p: (p.kind != "index", p.kind == "log", p.title.lower()))
            for page in files:
                label = "Overview" if page.kind == "index" else page.title
                here = ' aria-current="page"' if page is current else ""
                lines.append(
                    f'<li>{marker(page)}<a href="{relurl(current.out, page.out)}"{here}>{esc(label)}</a></li>'
                )
            for name in sorted(node["dirs"], key=str.lower):
                child = prefix / name
                inner = node["dirs"][name]
                if not inner["dirs"] and len(inner["files"]) == 1:
                    # A folder holding one document is a link, labelled by the
                    # folder (which is usually the better short name).
                    only = inner["files"][0]
                    here = ' aria-current="page"' if only is current else ""
                    lines.append(
                        f'<li>{marker(only)}<a href="{relurl(current.out, only.out)}"{here}>{esc(name)}</a></li>'
                    )
                    continue
                opened = " open" if child in ancestors else ""
                lines.append(f"<li><details{opened}><summary>{esc(name)}</summary>")
                lines.append(render(inner, child))
                lines.append("</details></li>")
            lines.append("</ul>")
            return "\n".join(lines)

        return render(root, PurePosixPath("."))

    def _plate(self, page: Page, up: str) -> str:
        meta = page.meta
        rows = []

        def row(label: str, value: str) -> None:
            rows.append(f"<dt>{esc(label)}</dt><dd>{value}</dd>")

        row("Type", f'<a href="{search_href(up, f"type:\"{page.type}\"")}">{esc(page.type)}</a>')
        resource = meta.get("resource")
        if resource:
            text = str(resource)
            row("Resource", f'<a class="external" rel="noopener" href="{esc(text)}">{esc(text)}</a>'
                if SCHEME.match(text) else f"<code>{esc(text)}</code>")
        tags = meta.get("tags")
        if isinstance(tags, list) and tags:
            chips = "".join(
                f'<a class="chip" href="{search_href(up, f"tag:{tag}")}">{esc(tag)}</a>' for tag in tags
            )
            row("Tags", chips)

        trust = [f'<span class="tier-name tier-{page.tier}">{TIER_LABEL[page.tier]}</span>']
        generated = meta.get("generated")
        if isinstance(generated, dict) and generated.get("by"):
            when = f" on {esc(generated['at'])}" if generated.get("at") else ""
            trust.append(f"Generated by {esc(generated['by'])}{when}")
        verified = meta.get("verified")
        events = [verified] if isinstance(verified, dict) else (verified if isinstance(verified, list) else [])
        for event in events:
            if isinstance(event, dict) and event.get("by"):
                when = f" on {esc(event['at'])}" if event.get("at") else ""
                trust.append(f"Verified by {esc(event['by'])}{when}")
        if meta.get("status") and meta.get("status") != "stable":
            trust.append(f'Status: <span class="status status-{esc(meta["status"])}">{esc(meta["status"])}</span>')
        if meta.get("stale_after"):
            trust.append(f"Stale after {esc(meta['stale_after'])}")
        row("Trust", "<br>".join(trust))

        sources = meta.get("sources")
        if isinstance(sources, list) and sources:
            items = []
            for source in sources:
                if not isinstance(source, dict) or not source.get("resource"):
                    continue
                target = str(source["resource"])
                label = esc(source.get("title") or target)
                items.append(
                    f'<li><a class="external" rel="noopener" href="{esc(target)}">{label}</a></li>'
                    if SCHEME.match(target) else f"<li>{label} <code>{esc(target)}</code></li>"
                )
            if items:
                row("Sources", f'<ul class="plain">{"".join(items)}</ul>')

        lede = f'<p class="lede">{esc(page.description)}</p>' if page.description else ""
        return f'<section class="plate" aria-label="About this document">{lede}<dl>{"".join(rows)}</dl></section>'

    def _crumbs(self, page: Page, up: str) -> str:
        parts = [f'<a href="{up}index.html">{esc(self.title)}</a>']
        if page.bundle:
            index = self.by_src.get(os.path.join(self.roots[page.bundle], "index.md"))
            parts.append(
                f'<a href="{relurl(page.out, index.out)}">{esc(page.bundle)}</a>' if index else esc(page.bundle)
            )
        for i, name in enumerate(page.rel.parts[:-1]):
            sub = self.by_src.get(os.path.join(self.roots[page.bundle], *page.rel.parts[: i + 1], "index.md"))
            parts.append(f'<a href="{relurl(page.out, sub.out)}">{esc(name)}</a>' if sub else esc(name))
        return '<nav class="crumbs" aria-label="Breadcrumb">' + '<span class="sep">/</span>'.join(parts) + "</nav>"

    def _shell(self, page: Page | None, up: str, main: str, side: str, rail: str, title: str, scripts: str = "") -> str:
        bundles = "".join(
            f'<a href="{up}{quote(name)}/index.html"{" aria-current=\"true\"" if page and page.bundle == name else ""}>{esc(name)}</a>'
            for name in self.roots
        )
        mermaid = f'<script src="{up}assets/mermaid.min.js"></script>' if self.mermaid else ""
        return f"""<!doctype html>
<html lang="en" data-theme="{self.theme}" data-themes="{' '.join(THEMES)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title if title == self.title else f"{title} | {self.title}")}</title>
<link rel="stylesheet" href="{up}assets/style.css">
<script src="{up}assets/theme.js"></script>
{mermaid}
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="top">
<a class="brand" href="{up}index.html">{esc(self.title)}</a>
<nav class="bundles" aria-label="Bundles">{bundles}</nav>
<form action="{up}search.html" role="search"><input type="search" name="q" placeholder="Search" aria-label="Search" title="Press / to search" autocomplete="off"></form>
</header>
<div class="layout">
<nav class="side" aria-label="Documents">{f'<details class="navwrap" open><summary>Browse {esc(page.bundle)}</summary>{side}</details>' if side else ""}</nav>
<main id="main">{main}</main>
<aside class="rail">{rail}</aside>
</div>
<footer>
<p>Built from {len(self.pages)} documents in the <a class="external" rel="noopener" href="{SPEC_URL}">Open Knowledge Format</a> v{okf.OKF_VERSION}.</p>
<label class="themepick" hidden>Theme <select id="theme">{"".join(f'<option value="{key}">{esc(label)}</option>' for key, label in THEMES.items())}</select></label>
</footer>
{scripts}<script src="{up}assets/app.js"></script>
</body>
</html>
"""

    def page_html(self, page: Page) -> str:
        up = "../" * (len(page.out.parts) - 1)
        lead, body = self.render_body(page)
        plate = self._plate(page, up) if page.kind == "concept" else ""
        stale = f' data-stale-after="{esc(page.meta["stale_after"])}"' if page.meta.get("stale_after") else ""
        tier = f" tier-{page.tier}" if page.tier else ""
        main = (
            f'{self._crumbs(page, up)}<article class="doc{tier}"{stale}>{lead}{plate}'
            f'<div class="prose">{body}</div></article>'
        )
        rail = []
        if len(page.toc) >= 2:
            items = "".join(
                f'<li class="l{level}"><a href="#{esc(ident)}">{esc(text)}</a></li>' for level, ident, text in page.toc
            )
            rail.append(f'<section><h2>On this page</h2><ul>{items}</ul></section>')
        linked = self.backlinks.get(page.out, [])
        if linked:
            items = "".join(
                f'<li><a href="{relurl(page.out, p.out)}">{esc(p.title)}</a></li>'
                for p in sorted(linked, key=lambda p: p.title.lower())
            )
            rail.append(f'<section><h2>Linked from</h2><ul>{items}</ul></section>')
        return self._shell(page, up, main, self._tree(page), "".join(rail), page.title)

    def landing_html(self) -> str:
        sections = []
        for name, root in self.roots.items():
            members = [p for p in self.pages if p.bundle == name and p.kind == "concept"]
            tiers: dict[str, int] = {}
            types: dict[str, int] = {}
            for page in members:
                tiers[page.tier] = tiers.get(page.tier, 0) + 1
                types[page.type] = types.get(page.type, 0) + 1
            index = self.by_src.get(os.path.join(root, "index.md"))
            href = f"{quote(name)}/index.html" if index else "#"
            type_links = ", ".join(
                f'<a href="{search_href("", f"bundle:{name} type:\"{t}\"")}">{esc(t)}</a> {n}'
                for t, n in sorted(types.items(), key=lambda kv: (-kv[1], kv[0].lower()))
            )
            trust = ", ".join(f"{n} {TIER_LABEL[t].lower()}" for t, n in tiers.items())
            sections.append(
                f'<section class="bundle"><h2><a href="{href}">{esc(name)}</a></h2>'
                f"<p>{len(members)} documents. {esc(trust)}.</p><p class=\"types\">{type_links}</p></section>"
            )
        start = next((p for p in self.pages if p.out.with_suffix(".md").as_posix() == self.start), None)
        note = (
            f'<p>Start with <a href="{relurl(PurePosixPath("index.html"), start.out)}">{esc(start.title)}</a>.</p>'
            if start
            else ""
        )
        main = (
            f"<article class=\"doc landing\"><h1>{esc(self.title)}</h1>"
            f'<p class="lede">{esc(self.subtitle)}</p>{note}{"".join(sections)}</article>'
        )
        return self._shell(None, "", main, "", "", self.title)

    def search_html(self) -> str:
        main = (
            '<article class="doc"><h1>Search</h1>'
            '<form action="search.html" role="search" class="big"><input id="q" type="search" name="q" '
            'aria-label="Search the documents" autocomplete="off" autofocus></form>'
            '<p class="hint">Words must all match. Narrow with <code>type:Guide</code>, <code>tag:vault</code>, '
            '<code>bundle:modules</code> or <code>trust:unverified</code>; quote multi-word values.</p>'
            '<ol id="results" class="results"></ol></article>'
        )
        # The index must load before app.js, which reads window.OKF_INDEX when it runs.
        return self._shell(None, "", main, "", "", "Search", scripts='<script src="assets/search-index.js"></script>\n')

    def search_index(self) -> str:
        records = []
        for page in self.pages:
            if page.kind != "concept":
                continue  # indexes and logs are navigation and history, not answers
            tags = page.meta.get("tags") if isinstance(page.meta.get("tags"), list) else []
            records.append(
                {
                    "u": quote(page.out.as_posix()),
                    "t": page.title,
                    "d": page.description,
                    "y": page.type,
                    "b": page.bundle,
                    "g": [str(t) for t in tags],
                    "r": page.tier or "",
                    "x": page.text,
                }
            )
        return "window.OKF_INDEX = " + json.dumps(records, ensure_ascii=False, separators=(",", ":")) + ";\n"

    # output ----------------------------------------------------------------

    def build(self, out: Path) -> dict:
        if out.exists():
            if any(out.iterdir()) and not (out / MARKER).exists():
                raise ValueError(f"{out} exists, is not empty and was not made by okf site")
            shutil.rmtree(out)
        (out / "assets").mkdir(parents=True)
        (out / MARKER).write_text("built by okf site\n", encoding="utf-8")

        def write(rel: str | PurePosixPath, text: str) -> None:
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")

        for page in self.pages:
            write(page.out, self.page_html(page))
        write("index.html", self.landing_html())
        write("search.html", self.search_html())
        write("assets/search-index.js", self.search_index())
        for name in ("style.css", "theme.js", "app.js"):
            shutil.copyfile(ASSETS / name, out / "assets" / name)
        if self.mermaid:
            shutil.copyfile(self.mermaid, out / "assets" / "mermaid.min.js")
        for site_path, source in sorted(self.assets.items()):
            target = out / site_path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        problems = verify_site(out)
        return {"pages": len(self.pages), "assets": len(self.assets), "problems": problems}


# ── Verification ─────────────────────────────────────────────────────────────


class _Refs(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.refs: list[str] = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if value and key in ("href", "src", "action"):
                self.refs.append(value)


def verify_site(root: Path) -> list[str]:
    """Every local href, src and form action in every page must exist."""
    problems = []
    for page in sorted(root.rglob("*.html")):
        parser = _Refs()
        parser.feed(page.read_text(encoding="utf-8"))
        for ref in parser.refs:
            if ref.startswith("#") or SCHEME.match(ref) or ref.startswith("//"):
                continue
            bare = unquote(re.split(r"[?#]", ref, maxsplit=1)[0])
            if bare and not (page.parent / bare).resolve().exists():
                problems.append(f"{page.relative_to(root).as_posix()}: missing {ref}")
    return problems
