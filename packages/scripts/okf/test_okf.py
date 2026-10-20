import tempfile
import textwrap
import unittest
from pathlib import Path

import okf


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(text).lstrip("\n"), encoding="utf-8")
    return path


class Tmp(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.root = Path(self._dir.name) / "bundle"
        self.root.mkdir()


class SplitFrontmatter(unittest.TestCase):
    def test_none(self):
        self.assertEqual(okf.split_frontmatter("# Hi\n"), (None, "# Hi\n"))

    def test_basic(self):
        raw, body = okf.split_frontmatter("---\ntype: A\n---\n# Hi\n")
        self.assertEqual(raw, "type: A\n")
        self.assertEqual(body, "# Hi\n")

    def test_empty_and_crlf(self):
        self.assertEqual(okf.split_frontmatter("---\n---\nbody"), ("", "body"))
        raw, body = okf.split_frontmatter("---\r\ntype: A\r\n---\r\nbody")
        self.assertEqual(raw, "type: A\r\n")
        self.assertEqual(body, "body")

    def test_unterminated(self):
        with self.assertRaises(ValueError):
            okf.split_frontmatter("---\ntype: A\n# Hi\n")

    def test_horizontal_rule_later_is_not_frontmatter(self):
        self.assertIsNone(okf.split_frontmatter("# Hi\n\n---\n\ntext\n")[0])

    def test_not_a_mapping(self):
        with self.assertRaises(ValueError):
            okf.load_meta("- a\n- b\n")

    def test_timestamps_stay_strings(self):
        meta = okf.load_meta("stale_after: 2026-06-30T14:00:00Z\nverified: { by: human:a, at: 2026-06-25T09:00:00+00:00 }\n")
        self.assertEqual(meta["stale_after"], "2026-06-30T14:00:00Z")
        self.assertEqual(meta["verified"]["at"], "2026-06-25T09:00:00+00:00")


class Validate(unittest.TestCase):
    def test_clean(self):
        meta = okf.load_meta(textwrap.dedent("""\
            type: Metric
            tags: [a, b]
            status: stable
            generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
            verified: { by: human:ahormati, at: 2026-06-25T09:00:00Z }
            stale_after: 2026-09-23T00:00:00Z
            sources:
              - { id: a, resource: https://example.com, author: team/x }
            """))
        self.assertEqual(okf.validate_meta(meta), [])

    def test_bare_verified_mapping_equals_one_element_list(self):
        one = okf.load_meta("type: A\nverified: { by: human:a, at: 2026-06-25T09:00:00Z }\n")
        many = okf.load_meta("type: A\nverified:\n  - { by: human:a, at: 2026-06-25T09:00:00Z }\n")
        self.assertEqual(okf.validate_meta(one), [])
        self.assertEqual(okf.trust_tier(one), okf.trust_tier(many))

    def test_problems(self):
        meta = okf.load_meta(textwrap.dedent("""\
            type: A
            status: live
            stale_after: 2026-09-23
            generated: { at: 2026-06-20T22:53:05Z }
            verified: [{ by: bob, at: 2026-06-25T09:00:00 }]
            sources: [{ title: no resource }]
            tags: nope
            """))
        text = "\n".join(okf.validate_meta(meta))
        for expected in ("status", "stale_after", "generated needs", "verified.by", "verified.at", "sources entry", "tags"):
            self.assertIn(expected, text)

    def test_attested_computation_needs_runtime(self):
        self.assertIn("runtime", "\n".join(okf.validate_meta({"type": "Attested Computation"})))

    def test_trust_tiers(self):
        self.assertEqual(okf.trust_tier({}), "unverified")
        self.assertEqual(okf.trust_tier({"verified": {"by": "process:n", "at": "x"}}), "machine-confirmed")
        self.assertEqual(
            okf.trust_tier({"verified": [{"by": "process:n", "at": "x"}, {"by": "human:a", "at": "x"}]}),
            "human-reviewed",
        )


class Check(Tmp):
    def findings(self, **kwargs):
        return okf.check_bundle(self.root, **kwargs)

    def test_conformant_minimal(self):
        write(self.root, "a.md", "---\ntype: Thing\n---\nbody\n")
        report = self.findings()
        self.assertEqual((report.errors, report.warnings, report.concepts), ([], [], 1))

    def test_missing_frontmatter_and_type(self):
        write(self.root, "a.md", "# no frontmatter\n")
        write(self.root, "b.md", "---\ntitle: no type\n---\n")
        write(self.root, "c.md", "---\ntype: ''\n---\n")
        messages = sorted(f.message for f in self.findings().errors)
        self.assertEqual(len(messages), 3)
        self.assertTrue(all("frontmatter" in m or "type" in m for m in messages))

    def test_unknown_keys_and_types_are_fine(self):
        write(self.root, "a.md", "---\ntype: Whatever New\nmy_key: [1, 2]\n---\n")
        report = self.findings()
        self.assertEqual((report.errors, report.warnings), ([], []))

    def test_index_and_log_rules(self):
        write(self.root, "a.md", "---\ntype: T\n---\n")
        write(self.root, "index.md", '---\nokf_version: "0.2"\n---\n# T\n')
        write(self.root, "sub/x.md", "---\ntype: T\n---\n")
        write(self.root, "sub/index.md", "---\nokf_version: '0.2'\n---\n")
        write(self.root, "log.md", "# Log\n\n## 2026-05-22\n* **Update**: x\n\n## yesterday\n")
        errors = [str(f) for f in self.findings().errors]
        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any("sub/index.md" in e for e in errors))
        self.assertTrue(any("log.md" in e and "yesterday" in e for e in errors))

    def test_reserved_files_are_not_concepts(self):
        write(self.root, "index.md", "# T\n")
        write(self.root, "log.md", "# Log\n")
        self.assertEqual(self.findings().concepts, 0)

    def test_log_order_is_advice(self):
        write(self.root, "log.md", "# Log\n\n## 2026-01-01\n* a\n\n## 2026-02-01\n* b\n")
        report = self.findings()
        self.assertEqual(report.errors, [])
        self.assertEqual(len(report.warnings), 1)

    def test_broken_links_only_warn(self):
        write(self.root, "a.md", """\
            ---
            type: T
            ---
            [ok](./b.md) [abs](/sub/c.md) [gone](./nope.md) [web](https://x.y/z.md)
            [anchor](#top) [frag](b.md#sec)

            ```
            [in code](./ignored.md)
            ```
            """)
        write(self.root, "b.md", "---\ntype: T\n---\n")
        write(self.root, "sub/c.md", "---\ntype: T\n---\n")
        report = self.findings()
        self.assertEqual(report.errors, [])
        self.assertEqual([f.message for f in report.warnings], ["broken link: ./nope.md"])

    def test_exclude(self):
        write(self.root, "a.md", "no frontmatter\n")
        write(self.root, "skip/b.md", "no frontmatter\n")
        report = self.findings(exclude=("skip/*",))
        self.assertEqual([f.path for f in report.errors], ["a.md"])

    def test_tier_counts(self):
        write(self.root, "a.md", "---\ntype: T\n---\n")
        write(self.root, "b.md", "---\ntype: T\nverified: { by: human:a, at: 2026-06-25T09:00:00Z }\n---\n")
        self.assertEqual(self.findings().tiers, {"unverified": 1, "machine-confirmed": 0, "human-reviewed": 1})


class Derive(unittest.TestCase):
    def description(self, body):
        return okf.derive_description(textwrap.dedent(body).lstrip("\n"))

    def test_first_prose_paragraph_first_sentence(self):
        self.assertEqual(
            self.description("""\
                # Title

                [![Badge](x.svg)](y)

                > **Note** a quote

                | a | b |
                |---|---|

                Runs the **thing** with `code`. A second sentence.
                """),
            "Runs the thing with code.",
        )

    def test_heading_glued_to_text(self):
        self.assertEqual(self.description("# T\nSome text here.\n"), "Some text here.")

    def test_skips_lists_and_fences(self):
        self.assertEqual(
            self.description("""\
                # T

                * item one
                  continuation line

                ```
                code. here
                ```

                Real prose.
                """),
            "Real prose.",
        )

    def test_lead_in_to_a_list_is_not_a_description(self):
        self.assertEqual(
            self.description("""\
                # T

                Modules involved:

                * a

                What it really does.
                """),
            "What it really does.",
        )

    def test_none_when_no_prose(self):
        self.assertIsNone(self.description("# T\n\n* a\n* b\n"))

    def test_long_is_cut_on_a_word(self):
        out = okf.derive_description("word " * 100, limit=50)
        self.assertLessEqual(len(out), 51)
        self.assertTrue(out.endswith("…"))

    def test_title(self):
        self.assertEqual(okf.derive_title("text\n# Home Assistant (`fmf.x`)\n", Path("a.md")), "Home Assistant (fmf.x)")
        self.assertEqual(okf.derive_title("```\n# not a title\n```\n", Path("nix-loops.md")), "Nix loops")


class Migrate(Tmp):
    def populate(self):
        write(self.root, "README.md", "# Bundle\n\nThe overview. More.\n")
        write(self.root, "services/niks3/README.md", "# niks3\n\nBinary cache.\n")
        write(self.root, "services/niks3/default.nix", "{}\n")
        write(self.root, "services/niks3/DESIGN.md", "# Design\n\nWhy.\n")
        write(self.root, "has-fm.md", "---\ntype: Custom\ncustom: keep\n---\n# Kept\n")

    def test_plan_and_apply(self):
        self.populate()
        bundle = self.root
        bundle = bundle.rename(bundle.parent / "modules")
        changes = okf.plan_migration(bundle)
        self.assertEqual(
            sorted(c.path.relative_to(bundle).as_posix() for c in changes),
            ["README.md", "services/niks3/DESIGN.md", "services/niks3/README.md"],
        )
        by_name = {c.path.relative_to(bundle).as_posix(): c.meta for c in changes}
        self.assertEqual(by_name["README.md"]["type"], "Overview")
        self.assertEqual(by_name["services/niks3/README.md"]["type"], "NixOS Module")
        self.assertEqual(by_name["services/niks3/README.md"]["resource"], "./default.nix")
        self.assertEqual(by_name["services/niks3/README.md"]["tags"], ["services", "niks3"])
        self.assertEqual(by_name["services/niks3/DESIGN.md"]["type"], "Design")
        self.assertNotIn("resource", by_name["services/niks3/DESIGN.md"])

    def test_never_writes_trust_fields(self):
        self.populate()
        for change in okf.plan_migration(self.root):
            self.assertFalse({"generated", "verified", "status", "stale_after", "sources"} & set(change.meta))

    def test_result_is_conformant_and_idempotent(self):
        self.populate()
        before = (self.root / "has-fm.md").read_text()
        for change in okf.plan_migration(self.root):
            change.path.write_text(change.text, encoding="utf-8")
        self.assertEqual((self.root / "has-fm.md").read_text(), before)
        self.assertEqual(okf.check_bundle(self.root).errors, [])
        self.assertEqual(okf.plan_migration(self.root), [])

    def test_body_is_preserved_byte_for_byte(self):
        original = "# Title\r\n\r\nText with\ttab.\r\n"
        path = write(self.root, "a.md", "x")
        path.write_bytes(original.encode())
        (change,) = okf.plan_migration(self.root)
        self.assertTrue(change.text.endswith(original))
        self.assertIn("\r\n", change.text.split("# Title")[0])

    def test_tricky_values_round_trip(self):
        write(self.root, "a.md", '# Title: with "quotes" #1\n\nUses key: value, and yes. Next.\n')
        (change,) = okf.plan_migration(self.root)
        raw, _ = okf.split_frontmatter(change.text)
        meta = okf.load_meta(raw)
        self.assertEqual(meta["title"], 'Title: with "quotes" #1')
        self.assertEqual(meta["description"], "Uses key: value, and yes.")

    def test_frontmatter_is_a_block_mapping_with_flow_lists(self):
        write(self.root, "a.md", "# A\n\nText.\n")
        write(self.root, "sub/b.md", "# B\n\nText.\n")
        by_name = {c.path.name: c.text for c in okf.plan_migration(self.root)}
        self.assertTrue(by_name["a.md"].startswith("---\ntype: Guide\ntitle: A\ndescription: Text.\n---\n\n# A"))
        self.assertIn("\ntags: [sub]\n", by_name["b.md"])
        for text in by_name.values():
            self.assertNotIn("{", text.split("---")[1])

    def test_systems_hosts(self):
        bundle = self.root.rename(self.root.parent / "systems")
        write(bundle, "x86_64-linux/webb/README.md", "# webb\n\nA host.\n")
        write(bundle, "x86_64-linux/webb/default.nix", "{}\n")
        (change,) = okf.plan_migration(bundle)
        self.assertEqual(change.meta["type"], "Host")
        self.assertEqual(change.meta["tags"], ["webb"])


class Index(Tmp):
    def populate(self):
        write(self.root, "b.md", "---\ntype: Guide\ntitle: Beta\ndescription: Second.\n---\n")
        write(self.root, "a.md", "---\ntype: Guide\ntitle: Alpha\n---\n")
        write(self.root, "z.md", "---\ntype: Design\ntitle: Zed [x]\ndescription: Last.\n---\n")
        write(self.root, "sub dir/README.md", "---\ntype: Overview\ntitle: Sub\ndescription: The sub.\n---\n")
        write(self.root, "sub dir/other.md", "---\ntype: Guide\n---\n")
        write(self.root, "empty/.keep", "")

    def test_root_index(self):
        self.populate()
        root = okf.plan_indexes(self.root)[self.root / "index.md"]
        self.assertTrue(root.startswith('---\nokf_version: "0.2"\n---\n'))
        self.assertLess(root.index("# Design"), root.index("# Guide"))
        self.assertLess(root.index("[Alpha]"), root.index("[Beta]"))
        self.assertIn("* [Beta](b.md) - Second.", root)
        self.assertIn("* [Alpha](a.md)\n", root)
        self.assertIn(r"[Zed \[x\]](z.md) - Last.", root)
        self.assertIn("* [sub dir](sub%20dir/) - The sub.", root)
        self.assertNotIn("empty", root)

    def test_subdirectory_index_has_no_frontmatter(self):
        self.populate()
        sub = okf.plan_indexes(self.root)[self.root / "sub dir" / "index.md"]
        self.assertFalse(sub.startswith("---"))
        self.assertNotIn(self.root / "empty" / "index.md", okf.plan_indexes(self.root))

    def test_a_lone_concept_gets_no_index_and_is_linked_directly(self):
        self.populate()
        write(self.root, "solo/README.md", "---\ntype: Overview\ntitle: Solo\ndescription: One.\n---\n")
        indexes = okf.plan_indexes(self.root)
        self.assertNotIn(self.root / "solo" / "index.md", indexes)
        self.assertIn("* [solo](solo/README.md) - One.", indexes[self.root / "index.md"])

    def test_a_directory_with_only_subdirectories_gets_an_index(self):
        write(self.root, "a/b/x.md", "---\ntype: T\n---\n")
        indexes = okf.plan_indexes(self.root)
        self.assertIn(self.root / "a" / "index.md", indexes)
        self.assertNotIn(self.root / "a" / "b" / "index.md", indexes)
        self.assertIn("(b/x.md)", indexes[self.root / "a" / "index.md"])

    def test_generated_indexes_are_conformant_and_stable(self):
        self.populate()
        for path, content in okf.stale_indexes(self.root).items():
            path.write_text(content, encoding="utf-8")
        self.assertEqual(okf.stale_indexes(self.root), {})
        self.assertEqual(okf.check_bundle(self.root).errors, [])

    def test_stale_after_edit(self):
        self.populate()
        for path, content in okf.stale_indexes(self.root).items():
            path.write_text(content, encoding="utf-8")
        (self.root / "a.md").write_text("---\ntype: Guide\ntitle: Alpha\ndescription: New.\n---\n")
        self.assertEqual(list(okf.stale_indexes(self.root)), [self.root / "index.md"])


class Cli(Tmp):
    def test_check_exit_codes(self):
        write(self.root, "a.md", "---\ntype: T\nstatus: live\n---\n")
        self.assertEqual(okf.main(["check", str(self.root)]), 0)
        self.assertEqual(okf.main(["check", "--strict", str(self.root)]), 1)
        write(self.root, "b.md", "no frontmatter\n")
        self.assertEqual(okf.main(["check", str(self.root)]), 1)

    def test_migrate_dry_run_changes_nothing(self):
        path = write(self.root, "a.md", "# A\n\nText.\n")
        self.assertEqual(okf.main(["migrate", str(self.root)]), 0)
        self.assertEqual(path.read_text(), "# A\n\nText.\n")
        self.assertFalse((self.root / "index.md").exists())

    def test_migrate_write_then_check_and_index(self):
        write(self.root, "a.md", "# A\n\nText.\n")
        self.assertEqual(okf.main(["migrate", "--write", "--date", "2026-10-19", str(self.root)]), 0)
        self.assertEqual(okf.main(["check", "--strict", str(self.root)]), 0)
        self.assertEqual(okf.main(["index", str(self.root)]), 0)
        self.assertIn("## 2026-10-19", (self.root / "log.md").read_text())
        (self.root / "a.md").write_text("---\ntype: T\ndescription: changed\n---\n")
        self.assertEqual(okf.main(["index", str(self.root)]), 1)
        self.assertEqual(okf.main(["index", "--write", str(self.root)]), 0)
        self.assertEqual(okf.main(["index", str(self.root)]), 0)


if __name__ == "__main__":
    unittest.main()
