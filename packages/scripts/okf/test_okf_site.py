import json
import re
import tempfile
import textwrap
import unittest
from pathlib import Path

import okf

try:
    import okf_site
except ImportError:  # the markdown libraries are only in the Nix environment
    okf_site = None


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(text).lstrip("\n"), encoding="utf-8")
    return path


@unittest.skipIf(okf_site is None, "markdown-it-py, mdit-py-plugins and pygments are not installed")
class SiteTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.tmp = Path(self._dir.name)
        self.docs = self.tmp / "docs"
        self.systems = self.tmp / "systems"
        self.out = self.tmp / "out"

    def populate(self):
        write(self.docs, "a.md", """\
            ---
            type: Guide
            title: Alpha
            description: First doc.
            tags: [one, two]
            ---
            # Alpha

            See [beta](./b.md#part), [abs](/sub/c.md), [gone](./nope.md), [web](https://example.com/x),
            [code file](./default.nix) and [dir](sub/).

            ![local](images/pic.png) ![remote](https://example.com/badge.svg) ![missing](images/none.png)

            ```nix
            { enable = true; }
            ```

            ## Second part

            ### Detail
            """)
        write(self.docs, "b.md", "---\ntype: Reference\ntitle: Beta\n---\n# Beta\n\nBody about vault.\n")
        write(self.docs, "sub/c.md", "---\ntype: Guide\ntitle: Gamma\n---\n# Gamma\n")
        write(self.docs, "sub/d.md", "---\ntype: Guide\n---\n# Delta\n")
        write(self.docs, "images/pic.png", "png")
        write(self.docs, "lone/README.md", "---\ntype: Overview\ntitle: Long descriptive title\n---\n# Long descriptive title\n")
        write(self.systems, "x86_64-linux/webb/README.md", """\
            ---
            type: Host
            title: webb
            verified: { by: human:me, at: 2026-06-25T09:00:00Z }
            stale_after: 2026-09-23T00:00:00Z
            ---
            # webb

            ![photo](../../../docs/images/pic.png)
            """)
        write(self.docs, "xss.md", "---\ntype: Guide\ntitle: '<script>alert(1)</script>'\n---\nText\n")
        for bundle in (self.docs, self.systems):
            for path, content in okf.stale_indexes(bundle).items():
                path.write_text(content, encoding="utf-8")
        write(self.docs, "log.md", "# Update Log\n\n## 2026-10-19\n* **Initialization**: x\n")

    def build(self, **kwargs):
        self.populate()
        site = okf_site.Site([self.docs, self.systems], "Test site", "Sub.", **kwargs)
        summary = site.build(self.out)
        return site, summary

    def html(self, rel: str) -> str:
        return (self.out / rel).read_text(encoding="utf-8")

    def test_builds_every_page_and_verifies_clean(self):
        _, summary = self.build()
        self.assertEqual(summary["problems"], [])
        for rel in ("index.html", "search.html", "assets/style.css", "assets/theme.js", "assets/app.js", "assets/search-index.js", "assets/campground-badge.png",
                    "docs/a.html", "docs/index.html", "docs/log.html", "docs/sub/index.html",
                    "systems/x86_64-linux/webb/README.html", "docs/images/pic.png"):
            self.assertTrue((self.out / rel).is_file(), rel)

    def test_bundles_without_index_files_still_get_index_pages(self):
        # Nothing here has run `okf index --write`: the site must not dead-end.
        write(self.docs, "a.md", "---\ntype: Guide\ntitle: Alpha\ndescription: First.\n---\n# Alpha\n")
        write(self.docs, "sub/b.md", "---\ntype: Guide\ntitle: Beta\n---\n# Beta\n")
        write(self.docs, "sub/c.md", "---\ntype: Guide\ntitle: Gamma\n---\n# Gamma\n")
        self.assertFalse((self.docs / "index.md").exists())
        summary = okf_site.Site([self.docs], "T", "S").build(self.out)
        self.assertEqual(summary["problems"], [])
        root = self.html("docs/index.html")
        self.assertIn('<a href="a.html">Alpha</a> - First.', root)
        self.assertIn('href="sub/index.html"', root)
        self.assertIn("Gamma", self.html("docs/sub/index.html"))
        self.assertEqual(len(re.findall(r"<h1[ >]", root)), 1)
        self.assertFalse((self.docs / "index.md").exists())  # the source tree is untouched

    def test_links_are_rewritten(self):
        self.build()
        page = self.html("docs/a.html")
        self.assertIn('href="b.html#part"', page)
        self.assertIn('href="sub/c.html"', page)
        self.assertIn('href="sub/index.html"', page)  # a directory links to its index
        self.assertIn('src="images/pic.png"', page)
        self.assertIn('rel="noopener"', page)

    def test_unresolvable_links_become_plain_text(self):
        self.build()
        page = self.html("docs/a.html")
        self.assertRegex(page, r'<span class="unresolved" title="\./nope\.md[^"]*">gone</span>')
        self.assertRegex(page, r'<span class="unresolved"[^>]*>code file</span>')
        self.assertRegex(page, r'<span class="unresolved">missing</span>')
        self.assertNotIn('href="./nope', page)

    def test_only_browser_assets_are_copied(self):
        write(self.docs, "default.nix", "{}\n")  # exists, and a.md links to it
        self.build()
        self.assertFalse((self.out / "docs" / "default.nix").exists())
        self.assertRegex(self.html("docs/a.html"), r'<span class="unresolved"[^>]*>code file</span>')
        self.assertTrue((self.out / "docs" / "images" / "pic.png").is_file())

    def test_remote_images_are_not_loaded(self):
        self.build()
        page = self.html("docs/a.html")
        self.assertNotIn('src="https://example.com/badge.svg"', page)
        self.assertIn('<a class="remote-image" href="https://example.com/badge.svg">remote</a>', page)

    def test_images_across_bundles_resolve_in_the_mirrored_layout(self):
        self.build()
        page = self.html("systems/x86_64-linux/webb/README.html")
        self.assertIn('src="../../../docs/images/pic.png"', page)
        self.assertTrue((self.out / "systems/x86_64-linux/webb/../../../docs/images/pic.png").resolve().is_file())

    def test_backlinks_come_from_documents_not_indexes(self):
        self.build()
        beta = self.html("docs/b.html")
        self.assertIn("<h2>Backlinks</h2>", beta)
        self.assertIn(">Alpha</a>", beta.split("<h2>Backlinks</h2>")[1])
        self.assertNotIn("index.html", beta.split("<h2>Backlinks</h2>")[1].split("</section>")[0])
        # Outgoing links are listed too, from the same Markdown links.
        self.assertIn(">Beta</a>", self.html("docs/a.html").split("<h2>Links to</h2>")[1])

    def graph(self, rel: str = "assets/graph-data.js") -> dict:
        text = self.html(rel)
        return json.loads(text.removeprefix("window.OKF_GRAPH = ").removesuffix(";\n"))

    def test_graph_has_a_node_per_document_and_an_edge_per_link(self):
        self.build()
        data = self.graph()
        self.assertEqual(
            sorted(n["t"] for n in data["nodes"]),
            sorted(["Alpha", "Beta", "Gamma", "Delta", "Long descriptive title", "webb", "<script>alert(1)</script>"]),
        )  # indexes and the log are navigation, not nodes
        url = [n["u"] for n in data["nodes"]]
        self.assertEqual(
            {(url[a], url[b]) for a, b in data["edges"]},
            {("docs/a.html", "docs/b.html"), ("docs/a.html", "docs/sub/c.html")},  # not the broken, code or directory links
        )
        alpha = next(n for n in data["nodes"] if n["t"] == "Alpha")
        self.assertEqual((alpha["y"], alpha["b"], alpha["g"]), ("Guide", "docs", ["one", "two"]))

    def test_graph_data_is_deterministic(self):
        self.build()
        first = self.html("assets/graph-data.js")
        self.out = self.tmp / "out2"
        self.build()
        self.assertEqual(first, self.html("assets/graph-data.js"))

    def test_graph_page_links_every_document_as_text(self):
        self.build()
        page = self.html("graph.html")
        self.assertIn('<canvas id="graph"', page)
        self.assertIn('src="assets/graph.js"', page)
        self.assertLess(page.index("assets/graph-data.js"), page.index("assets/graph.js"))
        self.assertIn("GRAPH // 7 documents, 2 links", page)
        for href, title in (("docs/a.html", "Alpha"), ("docs/sub/c.html", "Gamma"), ("systems/x86_64-linux/webb/README.html", "webb")):
            self.assertIn(f'<a href="{href}">{title}</a>', page)
        self.assertIn('<option value="two">two</option>', page)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", page)
        for rel in ("index.html", "docs/a.html"):
            self.assertIn('class="graphlink"', self.html(rel))

    def test_local_graph_is_only_on_documents_and_says_when_there_is_nothing(self):
        self.build()
        alpha = self.html("docs/a.html")
        self.assertRegex(alpha, r'<section class="localgraph" data-node="\d+" data-up="\.\./">')
        self.assertIn('href="../graph.html?focus=docs%2Fa.html"', alpha)
        self.assertIn('src="../assets/graph.js"', alpha)
        self.assertNotIn("localgraph", self.html("docs/index.html"))
        self.assertNotIn("graph.js", self.html("docs/log.html"))
        self.assertIn("No links to or from this document.", self.html("docs/sub/d.html"))

    def test_home_page_offers_the_real_entry_points(self):
        self.build()
        home = self.html("index.html")
        self.assertIn('href="search.html"', home)
        self.assertIn("7 documents, 2 links between them", home)
        self.assertIn('href="search.html?q=tag%3Aone"', home)

    def test_one_h1_per_page(self):
        self.build()
        for rel in ("docs/a.html", "docs/index.html", "docs/sub/index.html", "docs/log.html"):
            self.assertEqual(len(re.findall(r"<h1[ >]", self.html(rel))), 1, rel)

    def test_page_without_a_heading_gets_its_title(self):
        write(self.docs, "plain.md", "---\ntype: Guide\ntitle: No heading\n---\nJust text.\n")
        self.build()
        self.assertIn("<h1>No heading</h1>", self.html("docs/plain.html"))

    def test_titles_are_escaped(self):
        self.build()
        page = self.html("docs/xss.html")
        self.assertNotIn("<script>alert(1)</script>", page)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", page)

    def test_trust_rule_and_stale_marker(self):
        self.build()
        self.assertIn("doc tier-unverified", self.html("docs/a.html"))
        webb = self.html("systems/x86_64-linux/webb/README.html")
        self.assertIn("doc tier-human-reviewed", webb)
        self.assertIn('data-stale-after="2026-09-23T00:00:00Z"', webb)
        self.assertIn("Verified by human:me", webb)
        self.assertIn('<span class="vby">Verified by human:me', webb)  # one block line per fact, no <br>
        self.assertNotIn("<br>", webb.split('class="plate"')[1].split("</section>")[0])
        self.assertNotIn("tier-", self.html("search.html").split("<main")[1].split("</main>")[0])

    def test_tree_links_a_folder_with_one_document(self):
        self.build()
        tree = self.html("docs/a.html").split('<nav class="side"')[1].split("</nav>")[0]
        self.assertRegex(tree, r'<a href="lone/README\.html">lone</a>')
        self.assertIn("<summary>sub</summary>", tree)

    def test_syntax_highlighting_has_no_remote_assets(self):
        self.build()
        page = self.html("docs/a.html")
        self.assertIn('<code class="language-nix">', page)
        self.assertRegex(page, r'<span class="(k|kc|nb|n)[a-z]*">')
        self.assertNotRegex(page, r'<(script|link)[^>]*(src|href)="https?:')

    def test_search_index(self):
        self.build()
        raw = self.html("assets/search-index.js")
        self.assertTrue(raw.startswith("window.OKF_INDEX = "))
        records = json.loads(raw[len("window.OKF_INDEX = "):].rstrip().rstrip(";"))
        titles = {r["t"] for r in records}
        self.assertIn("Alpha", titles)
        self.assertNotIn("Update log", titles)  # history is not something to search for
        self.assertFalse(any(r["u"].endswith("log.html") for r in records))
        self.assertNotIn("Index", {r["y"] for r in records})  # navigation pages are not answers
        alpha = next(r for r in records if r["t"] == "Alpha")
        self.assertIn("See beta, abs, gone", alpha["x"])  # link syntax is stripped from snippets
        self.assertNotIn("](", alpha["x"])
        beta = next(r for r in records if r["t"] == "Beta")
        self.assertEqual((beta["y"], beta["b"], beta["r"]), ("Reference", "docs", "unverified"))
        self.assertIn("vault", beta["x"])
        self.assertEqual(next(r for r in records if r["t"] == "Alpha")["g"], ["one", "two"])

    def test_search_index_loads_before_the_search_code(self):
        self.build()
        page = self.html("search.html")
        self.assertLess(page.index("search-index.js"), page.index("assets/app.js"))
        self.assertNotIn("search-index.js", self.html("docs/a.html"))

    def test_themes_are_embedded_and_validated(self):
        self.build(theme="navy-mk2-light")
        page = self.html("docs/a.html")
        self.assertIn('data-theme="navy-mk2-light"', page)
        self.assertIn('data-themes="navy-mk2 navy-mk2-light"', page)
        self.assertIn('src="../assets/theme.js"', page)
        self.assertIn('<select id="theme">', page)
        with self.assertRaisesRegex(ValueError, "unknown theme"):
            okf_site.Site([self.docs], "T", "S", theme="navy")

    def test_navy_mk2_is_the_default_theme_with_a_light_variant(self):
        self.populate()
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), str(self.docs)]), 0)
        self.assertIn('data-theme="navy-mk2"', self.html("index.html"))
        css = self.html("assets/style.css")
        for theme, marker in (("navy-mk2", "#0a1222"), ("navy-mk2-light", "#f7f9fc")):
            self.assertIn(f'html[data-theme="{theme}"]', css)
            self.assertIn(marker, css)
        self.assertIn("jetbrains-mono-500.woff2", css)
        self.assertNotIn("usmc", css)
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--theme", "navy-mk2-light", str(self.docs)]), 0)
        self.assertIn('data-theme="navy-mk2-light"', self.html("index.html"))
        self.assertIn('"navy-mk2": "navy-mk2-light"', self.html("assets/theme.js"))

    def test_nix_identifiers_are_coloured_like_names(self):
        # Pygments leaves them as plain text; the design colours them, so they get the name class.
        html_out = okf_site._highlight('pkgs.fmf.okf.mkSite { name = "x"; }', "nix", None)
        self.assertIn('<span class="n">pkgs</span>', html_out)
        self.assertIn('<span class="n">mkSite</span>', html_out)
        self.assertNotIn('<span class="n"> </span>', html_out)  # whitespace stays plain
        self.assertNotIn('class="n"', okf_site._highlight("echo hi", "bash", None))

    def test_masthead_has_the_navy_mk2_emblem_and_the_graph_card_a_way_in(self):
        self.build()
        self.assertIn('<img class="emblem" src="assets/campground-badge.png" alt="" width="40" height="40">', self.html("index.html"))
        self.assertTrue((self.out / "assets" / "campground-badge.png").is_file())
        graph = self.html("assets/graph.js")
        for part in ('"legend-head"', '"Linked documents"', '"Open document"'):
            self.assertIn(part, graph)

    def test_every_page_has_the_same_chrome(self):
        # Home, search and graph used to drop the sidebar; the layout must not change between pages.
        self.build()
        for rel in ("index.html", "search.html", "graph.html", "docs/a.html", "docs/index.html", "docs/log.html"):
            page = self.html(rel)
            self.assertRegex(page, r'<nav class="side" id="docnav" aria-label="Documents"><details class="navwrap" open>', rel)
            self.assertIn('<nav class="bundles"', page, rel)
            self.assertIn('role="search"', page, rel)
            self.assertIn('<aside class="rail">', page, rel)
        home = self.html("index.html")
        self.assertIn('<a href="index.html" aria-current="page">Home</a>', home)
        self.assertIn('<a href="graph.html">Knowledge graph</a>', home)
        self.assertIn('<summary>docs</summary>', home)
        self.assertIn('<a href="docs/a.html">Alpha</a>', home)  # a bundle's top level
        self.assertIn('<a href="docs/sub/index.html">sub</a>', home)
        self.assertIn('aria-current="page">Knowledge graph</a>', self.html("graph.html"))

    def test_header_has_brand_tabs_search_and_actions(self):
        self.build(start="docs/b.md")
        page = self.html("docs/a.html")
        for part in ('class="brandrow"', 'class="bundles"', 'role="search"', 'class="top-actions"', 'id="modetoggle"'):
            self.assertIn(part, page)
        self.assertIn('<a class="cta" href="../docs/b.html">Get started</a>', page)
        bare = okf_site.Site([self.docs], "T", "S")  # no start page, so no button
        self.assertNotIn('class="cta"', bare.page_html(next(p for p in bare.pages if p.kind == "concept")))
        self.assertIn("@font-face", self.html("assets/style.css"))
        self.assertIn("fonts/space-grotesk-700.woff2", self.html("assets/style.css"))
        self.assertIn('src="../assets/campground-badge.png" alt="" width="40" height="40"', page)

    def test_theme_script_carries_the_theme_between_pages(self):
        self.build()
        script = self.html("assets/theme.js")
        self.assertIn('document.querySelectorAll("a[href]")', script)
        self.assertIn('input.name = "theme"', script)

    def test_local_mermaid_asset_is_embedded_when_requested(self):
        self.populate()
        mermaid = write(self.tmp, "mermaid.min.js", "window.mermaid = {};\n")
        site = okf_site.Site([self.docs], "T", "S", mermaid=str(mermaid))
        summary = site.build(self.out)
        self.assertEqual(summary["problems"], [])
        self.assertTrue((self.out / "assets" / "mermaid.min.js").is_file())
        self.assertIn('src="assets/mermaid.min.js"', self.html("index.html"))

    def test_landing_page_lists_bundles_and_start(self):
        self.build(start="docs/b.md")
        landing = self.html("index.html")
        self.assertIn('href="docs/index.html"', landing)
        self.assertIn('href="systems/index.html"', landing)
        self.assertIn("Start here", landing)
        self.assertIn('href="docs/b.html"', landing)

    def test_verify_reports_a_missing_target(self):
        self.build()
        (self.out / "assets" / "style.css").unlink()
        problems = okf_site.verify_site(self.out)
        self.assertTrue(any("missing" in p and "style.css" in p for p in problems))

    def test_bundle_names_must_be_unique(self):
        other = self.tmp / "elsewhere" / "docs"
        other.mkdir(parents=True)
        with self.assertRaises(ValueError):
            okf_site.Site([self.docs.parent / "docs", other], "t", "s")

    def test_never_clobbers_a_foreign_directory(self):
        self.populate()
        self.out.mkdir()
        (self.out / "precious.txt").write_text("keep")
        with self.assertRaises(ValueError):
            okf_site.Site([self.docs], "t", "s").build(self.out)
        self.assertTrue((self.out / "precious.txt").exists())

    def test_rebuild_replaces_a_previous_build(self):
        self.build()
        (self.out / "docs" / "stale.html").write_text("old")
        okf_site.Site([self.docs, self.systems], "t", "s").build(self.out)
        self.assertFalse((self.out / "docs" / "stale.html").exists())

    def test_cli(self):
        self.populate()
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--title", "T", "--theme", "navy-mk2-light", str(self.docs)]), 0)
        self.assertIn('data-theme="navy-mk2-light"', self.html("index.html"))
        self.assertEqual(okf.main(["site", "verify", str(self.out)]), 0)
        (self.out / "assets" / "app.js").unlink()
        self.assertEqual(okf.main(["site", "verify", str(self.out)]), 1)


if __name__ == "__main__":
    unittest.main()
