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
        for rel in ("index.html", "search.html", "assets/style.css", "assets/theme.js", "assets/app.js", "assets/search-index.js",
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
        self.assertIn("Linked from", beta)
        self.assertIn(">Alpha</a>", beta.split("Linked from")[1])
        self.assertNotIn("index.html", beta.split("Linked from")[1].split("</section>")[0])

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
        self.build(theme="lantern")
        page = self.html("docs/a.html")
        self.assertIn('data-theme="lantern"', page)
        self.assertIn('data-themes="field-manual trail-map manpage lantern toc okf-visualizer okf-visualizer-dark"', page)
        self.assertIn('src="../assets/theme.js"', page)
        self.assertIn('<select id="theme">', page)
        with self.assertRaisesRegex(ValueError, "unknown theme"):
            okf_site.Site([self.docs], "T", "S", theme="nope")

    def test_toc_theme_is_available_from_the_cli(self):
        self.populate()
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--theme", "toc", str(self.docs)]), 0)
        self.assertIn('data-theme="toc"', self.html("index.html"))

    def test_okf_visualizer_theme_is_available_from_the_cli(self):
        self.populate()
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--theme", "okf-visualizer", str(self.docs)]), 0)
        self.assertIn('data-theme="okf-visualizer"', self.html("index.html"))

    def test_okf_visualizer_dark_theme_is_available_from_the_cli(self):
        self.populate()
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--theme", "okf-visualizer-dark", str(self.docs)]), 0)
        self.assertIn('data-theme="okf-visualizer-dark"', self.html("index.html"))

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
        self.assertIn("Start with", landing)
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
        self.assertEqual(okf.main(["site", "build", "--out", str(self.out), "--title", "T", "--theme", "trail-map", str(self.docs)]), 0)
        self.assertIn('data-theme="trail-map"', self.html("index.html"))
        self.assertEqual(okf.main(["site", "verify", str(self.out)]), 0)
        (self.out / "assets" / "app.js").unlink()
        self.assertEqual(okf.main(["site", "verify", str(self.out)]), 1)


if __name__ == "__main__":
    unittest.main()
