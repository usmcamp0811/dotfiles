#!/usr/bin/env python3
"""okf: check, migrate and index Open Knowledge Format (OKF) v0.2 bundles.

A bundle is a directory of markdown files with YAML frontmatter. This tool
follows https://github.com/GoogleCloudPlatform/open-knowledge-format (SPEC.md).

  okf check   BUNDLE...   report spec violations (errors) and advice (warnings)
  okf migrate BUNDLE...   add frontmatter to markdown files that have none
  okf index   BUNDLE...   generate index.md files (progressive disclosure)

`migrate` and `index` only report what they would do unless given --write.
`migrate` never writes the trust fields (`generated`, `verified`): the spec keys
trust tiers off the `human:` actor prefix, so claiming a review that did not
happen would be false. A missing `verified` honestly means "unverified".
"""
from __future__ import annotations

import argparse
import datetime
import fnmatch
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote

import yaml

OKF_VERSION = "0.2"
RESERVED = ("index.md", "log.md")
SKIP_DIRS = {".git", "node_modules", "result", "__pycache__"}
STATUSES = ("draft", "stable", "deprecated")

TIMESTAMP = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)
ACTOR = re.compile(r"^(?:human:\S+|process:\S+|[^\s:/]+/\S+)$")
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCE = re.compile(r"^\s*(```|~~~)")


class _Loader(yaml.SafeLoader):
    """SafeLoader that keeps ISO timestamps as strings, so the explicit UTC offset
    the spec requires can be checked instead of being normalised away."""


_Loader.yaml_implicit_resolvers = {
    first: [
        (tag, rx)
        for tag, rx in resolvers
        if tag != "tag:yaml.org,2002:timestamp"
    ]
    for first, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}


# ── Parsing ──────────────────────────────────────────────────────────────────

_OPEN = re.compile(r"\A\ufeff?---[ \t]*\r?\n")
_CLOSE = re.compile(r"^---[ \t]*\r?$", re.M)


def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Return (frontmatter text or None, body). Raises ValueError if unterminated."""
    opened = _OPEN.match(text)
    if not opened:
        return None, text
    closed = _CLOSE.search(text, opened.end())
    if not closed:
        raise ValueError("frontmatter is not closed by a '---' line")
    body = text[closed.end() :]
    if body.startswith("\r\n"):
        body = body[2:]
    elif body.startswith("\n"):
        body = body[1:]
    return text[opened.end() : closed.start()], body


def load_meta(raw: str) -> dict:
    try:
        data = yaml.load(raw, Loader=_Loader)
    except yaml.YAMLError as err:
        raise ValueError(f"frontmatter is not valid YAML: {str(err).splitlines()[0]}")
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a YAML mapping")
    return data


def iter_markdown(bundle: Path, exclude: tuple[str, ...] = ()):
    for dirpath, dirnames, filenames in os.walk(bundle):
        dirnames[:] = sorted(
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        )
        for name in sorted(filenames):
            if not name.lower().endswith(".md"):
                continue
            path = Path(dirpath) / name
            rel = path.relative_to(bundle).as_posix()
            if any(fnmatch.fnmatch(rel, pattern) for pattern in exclude):
                continue
            yield path


# ── Checking ─────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Finding:
    level: str  # "error" or "warning"
    path: str
    message: str

    def __str__(self) -> str:
        return f"{self.level}: {self.path}: {self.message}"


def _is_timestamp(value) -> bool:
    return isinstance(value, str) and bool(TIMESTAMP.match(value))


def _actor_problem(value) -> str | None:
    if not isinstance(value, str) or not ACTOR.match(value):
        return (
            f"{value!r} is not an actor: use <producer>/<version>, "
            "human:<id> or process:<id>"
        )
    return None


def validate_meta(meta: dict) -> list[str]:
    """Advice for the optional families (§4.1, §5, §10). Never an error: consumers
    MUST NOT reject a concept for missing or odd optional fields (§11)."""
    problems: list[str] = []

    for key in ("title", "description", "resource"):
        if key in meta and not isinstance(meta[key], str):
            problems.append(f"{key} should be a string")
    tags = meta.get("tags")
    if tags is not None and not (
        isinstance(tags, list) and all(isinstance(tag, str) for tag in tags)
    ):
        problems.append("tags should be a list of strings")

    if "status" in meta and meta["status"] not in STATUSES:
        problems.append(f"status {meta['status']!r} is not one of {', '.join(STATUSES)}")
    if "stale_after" in meta and not _is_timestamp(meta["stale_after"]):
        problems.append("stale_after should be an ISO 8601 datetime with a UTC offset")

    generated = meta.get("generated")
    if generated is not None:
        if not isinstance(generated, dict) or "by" not in generated:
            problems.append("generated needs a 'by' actor")
        else:
            problem = _actor_problem(generated["by"])
            if problem:
                problems.append(f"generated.by: {problem}")
            if "at" in generated and not _is_timestamp(generated["at"]):
                problems.append("generated.at should be an ISO 8601 datetime with a UTC offset")

    verified = meta.get("verified")
    if verified is not None:
        events = [verified] if isinstance(verified, dict) else verified
        if not isinstance(events, list):
            problems.append("verified should be a { by, at } mapping or a list of them")
        else:
            for event in events:
                if not isinstance(event, dict) or "by" not in event or "at" not in event:
                    problems.append("each verified entry needs 'by' and 'at'")
                    continue
                problem = _actor_problem(event["by"])
                if problem:
                    problems.append(f"verified.by: {problem}")
                if not _is_timestamp(event["at"]):
                    problems.append("verified.at should be an ISO 8601 datetime with a UTC offset")

    sources = meta.get("sources")
    if sources is not None:
        if not isinstance(sources, list):
            problems.append("sources should be a list")
        else:
            for source in sources:
                if not isinstance(source, dict) or not source.get("resource"):
                    problems.append("each sources entry needs a 'resource'")
                    continue
                if "author" in source and _actor_problem(source["author"]):
                    problems.append(f"sources author: {_actor_problem(source['author'])}")
                if "last_modified" in source and not _is_timestamp(source["last_modified"]):
                    problems.append("sources last_modified should be an ISO 8601 datetime with a UTC offset")

    window = meta.get("usage_window")
    if window is not None and not (
        isinstance(window, dict)
        and _is_timestamp(window.get("from"))
        and _is_timestamp(window.get("to"))
    ):
        problems.append("usage_window needs ISO 8601 'from' and 'to'")

    if meta.get("type") == "Attested Computation" and not meta.get("runtime"):
        problems.append("an Attested Computation needs a 'runtime' (§10.2)")
    return problems


def trust_tier(meta: dict) -> str:
    """§5.3: unverified, machine-confirmed or human-reviewed."""
    verified = meta.get("verified")
    if not verified:
        return "unverified"
    events = [verified] if isinstance(verified, dict) else verified
    if isinstance(events, list):
        for event in events:
            by = event.get("by") if isinstance(event, dict) else None
            if isinstance(by, str) and by.startswith("human:"):
                return "human-reviewed"
    return "machine-confirmed"


def _strip_fences(body: str) -> str:
    out, fenced = [], False
    for line in body.splitlines():
        if FENCE.match(line):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return "\n".join(out)


def broken_links(bundle: Path, path: Path, body: str) -> list[str]:
    broken = []
    for target in LINK.findall(_strip_fences(body)):
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
            continue
        bare = unquote(re.split(r"[#?]", target, maxsplit=1)[0])
        if not bare.lower().endswith(".md"):
            continue
        resolved = (bundle / bare.lstrip("/")) if bare.startswith("/") else (path.parent / bare)
        if not resolved.is_file():
            broken.append(target)
    return broken


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)
    concepts: int = 0
    tiers: dict = field(default_factory=lambda: {
        "unverified": 0, "machine-confirmed": 0, "human-reviewed": 0,
    })

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.level == "error"]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.level == "warning"]


def check_bundle(bundle: Path, exclude: tuple[str, ...] = ()) -> Report:
    report = Report()
    for path in iter_markdown(bundle, exclude):
        rel = path.relative_to(bundle).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            report.findings.append(Finding("error", rel, "is not valid UTF-8"))
            continue
        if path.name == "index.md":
            _check_index(report, rel, text, root=path.parent == bundle)
        elif path.name == "log.md":
            _check_log(report, rel, text)
        else:
            _check_concept(report, bundle, path, rel, text)
    return report


def _check_concept(report: Report, bundle: Path, path: Path, rel: str, text: str) -> None:
    report.concepts += 1
    try:
        raw, body = split_frontmatter(text)
        if raw is None:
            report.findings.append(Finding("error", rel, "has no YAML frontmatter (§4)"))
            return
        meta = load_meta(raw)
    except ValueError as err:
        report.findings.append(Finding("error", rel, str(err)))
        return
    type_ = meta.get("type")
    if not isinstance(type_, str) or not type_.strip():
        report.findings.append(Finding("error", rel, "frontmatter needs a non-empty 'type' (§4.1)"))
    for problem in validate_meta(meta):
        report.findings.append(Finding("warning", rel, problem))
    for target in broken_links(bundle, path, body):
        report.findings.append(Finding("warning", rel, f"broken link: {target}"))
    report.tiers[trust_tier(meta)] += 1


def _check_index(report: Report, rel: str, text: str, root: bool) -> None:
    try:
        raw, _ = split_frontmatter(text)
        meta = load_meta(raw) if raw is not None else None
    except ValueError as err:
        report.findings.append(Finding("error", rel, str(err)))
        return
    if meta is None:
        return
    if not root:
        report.findings.append(Finding("error", rel, "index.md has no frontmatter outside the bundle root (§8)"))
    elif set(meta) - {"okf_version"}:
        report.findings.append(Finding("error", rel, "root index.md may only carry okf_version (§8)"))
    elif "okf_version" in meta and not isinstance(meta["okf_version"], str):
        report.findings.append(Finding("warning", rel, 'okf_version should be a string, e.g. "0.2"'))


def _check_log(report: Report, rel: str, text: str) -> None:
    dates = []
    for line in text.splitlines():
        match = re.match(r"^##\s+(.*?)\s*$", line)
        if not match:
            continue
        heading = match.group(1)
        try:
            dates.append(datetime.date.fromisoformat(heading))
        except ValueError:
            report.findings.append(Finding("error", rel, f"log heading {heading!r} is not an ISO 8601 date (§9)"))
    if dates != sorted(dates, reverse=True):
        report.findings.append(Finding("warning", rel, "log entries should be newest first (§9)"))


# ── Migration ────────────────────────────────────────────────────────────────

_TYPE_BY_NAME = (
    (re.compile(r"^DESIGN"), "Design"),
    (re.compile(r"^ARCHITECTURE"), "Architecture"),
    (re.compile(r"^(TEST|TESTS|TESTING)\b"), "Test Guide"),
    (re.compile(r"^TROUBLESHOOTING"), "Troubleshooting"),
    (re.compile(r"^CHANGELOG"), "Changelog"),
    (re.compile(r"^TODO"), "Todo"),
    (re.compile(r"^EXAMPLES"), "Examples"),
    (re.compile(r"^TUTORIAL"), "Tutorial"),
    (re.compile(r"QUICKSTART|QUICK-REF|INSTALL|RECOVERY|SETUP|MITIGATION"), "Runbook"),
    (re.compile(r"REFERENCE|^SECURITY|^SECRETS"), "Reference"),
    (re.compile(r"NOTES|LEVELUP|LOOPS|SEQUENCE"), "Note"),
)
_GENERIC_TAG_PARTS = {"nixos", "x86_64-linux", "aarch64-linux"}


def infer_type(bundle: Path, path: Path) -> str:
    rel = path.relative_to(bundle)
    stem = path.stem.upper()
    if stem == "README":
        owns_code = (path.parent / "default.nix").is_file()
        if bundle.name == "systems":
            return "Host" if owns_code or len(rel.parts) > 1 else "Overview"
        if owns_code:
            return "Home Manager Module" if rel.parts[0] == "home" else "NixOS Module"
        return "Overview"
    for pattern, type_ in _TYPE_BY_NAME:
        if pattern.search(stem):
            return type_
    return "Guide"


def derive_tags(bundle: Path, path: Path) -> list[str]:
    parts = path.relative_to(bundle).parts[:-1]
    return [p.lower() for p in parts if p.lower() not in _GENERIC_TAG_PARTS]


def strip_inline(text: str) -> str:
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("`", "").replace("**", "").replace("__", "")
    return re.sub(r"\s+", " ", text).strip(" *_")


def derive_title(body: str, path: Path) -> str:
    for line in _strip_fences(body).splitlines():
        match = re.match(r"^#\s+(.+?)\s*#*\s*$", line)
        if match:
            title = strip_inline(match.group(1))
            if title:
                return title
    name = re.sub(r"[-_]+", " ", path.stem).strip()
    return name[:1].upper() + name[1:] if name else path.stem


def derive_description(body: str, limit: int = 200) -> str | None:
    """First plain prose paragraph, cut to its first sentence."""
    # Blocks that are not prose: tables, images, html, admonitions, rules, lists,
    # quotes and indented code. A block is skipped whole, continuation lines included.
    skip = re.compile(r"^(\||!\[|<|\[!|---|\*\s|-\s|\+\s|\d+[.)]\s|>|\s{2,}|\t)")
    text = ""
    for block in re.split(r"\n\s*\n", _strip_fences(body)):
        lines = block.splitlines()
        while lines and lines[0].lstrip().startswith("#"):
            lines.pop(0)  # a heading directly above the prose
        if not lines or skip.match(lines[0]):
            continue
        text = strip_inline(" ".join(line.strip() for line in lines))
        if text.endswith(":"):
            text = ""  # a lead-in to a list or table ("Modules involved:"), not a summary
        if text:
            break
    if not text:
        return None
    first = re.split(r"(?<=[.!?])\s+(?=[A-Z])", text, maxsplit=1)[0]
    if len(first) > limit:
        first = first[:limit].rsplit(" ", 1)[0].rstrip(",;:") + "…"
    return first


def build_frontmatter(bundle: Path, path: Path, body: str) -> dict:
    meta: dict = {
        "type": infer_type(bundle, path),
        "title": derive_title(body, path),
    }
    description = derive_description(body)
    if description:
        meta["description"] = description
    if (path.parent / "default.nix").is_file() and path.stem.upper() == "README":
        meta["resource"] = "./default.nix"
    tags = derive_tags(bundle, path)
    if tags:
        meta["tags"] = tags
    return meta


def render_frontmatter(meta: dict, newline: str = "\n") -> str:
    # A block mapping like the spec's examples, with lists in flow style: [a, b].
    # (default_flow_style=None would flatten the whole mapping onto one line
    # whenever it has no list in it.)
    options = {"allow_unicode": True, "width": 10**6}
    lines = []
    for key, value in meta.items():
        if isinstance(value, list):
            rendered = yaml.safe_dump(value, default_flow_style=True, **options)
            lines.append(f"{key}: {rendered.strip()}")
        else:
            lines.append(yaml.safe_dump({key: value}, default_flow_style=False, **options).rstrip("\n"))
    return newline.join(["---", *lines, "---", ""]) + newline


@dataclass
class Change:
    path: Path
    meta: dict
    text: str  # the full new file content


def plan_migration(bundle: Path, exclude: tuple[str, ...] = ()) -> list[Change]:
    changes = []
    for path in iter_markdown(bundle, exclude):
        if path.name in RESERVED:
            continue
        # newline="" keeps CRLF files byte-for-byte: only the frontmatter is added.
        with open(path, encoding="utf-8", newline="") as handle:
            text = handle.read()
        if _OPEN.match(text):
            continue  # already has (or tries to have) frontmatter: never rewrite it
        newline = "\r\n" if "\r\n" in text else "\n"
        meta = build_frontmatter(bundle, path, text)
        changes.append(Change(path, meta, render_frontmatter(meta, newline) + text))
    return changes


# ── Indexes ──────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Concept:
    rel: PurePosixPath
    type: str
    title: str
    description: str


def read_concepts(bundle: Path, exclude: tuple[str, ...] = ()) -> list[Concept]:
    concepts = []
    for path in iter_markdown(bundle, exclude):
        if path.name in RESERVED:
            continue
        try:
            raw, body = split_frontmatter(path.read_text(encoding="utf-8"))
            meta = load_meta(raw) if raw is not None else {}
        except ValueError:
            continue  # `check` reports it; an index should not crash on it
        concepts.append(
            Concept(
                PurePosixPath(path.relative_to(bundle).as_posix()),
                str(meta.get("type") or "Concept"),
                str(meta.get("title") or derive_title(body, path)),
                " ".join(str(meta.get("description") or "").split()),
            )
        )
    return concepts


def _escape(text: str) -> str:
    return text.replace("[", "\\[").replace("]", "\\]")


def render_index(concepts: list[Concept], directory: PurePosixPath) -> str:
    here = [c for c in concepts if c.rel.parent == directory]
    children: dict[str, list[Concept]] = {}
    for concept in concepts:
        if concept.rel.parent != directory and directory in concept.rel.parents:
            first = concept.rel.relative_to(directory).parts[0]
            children.setdefault(first, []).append(concept)

    lines: list[str] = []
    if directory == PurePosixPath("."):
        lines += ["---", f'okf_version: "{OKF_VERSION}"', "---", ""]

    def entry(label: str, url: str, description: str) -> str:
        suffix = f" - {description}" if description else ""
        return f"* [{_escape(label)}]({url}){suffix}"

    for type_ in sorted({c.type for c in here}, key=str.lower):
        lines += [f"# {type_}", ""]
        for concept in sorted(
            (c for c in here if c.type == type_),
            key=lambda c: (c.title.lower(), c.rel.name.lower()),
        ):
            lines.append(entry(concept.title, quote(concept.rel.name), concept.description))
        lines.append("")

    if children:
        lines += ["# Subdirectories", ""]
        for name in sorted(children, key=str.lower):
            members = children[name]
            readme = next((m for m in members if m.rel.parent == directory / name and m.rel.stem.lower() == "readme"), None)
            description = (readme.description if readme else "") or (
                f"{len(members)} concept{'s' if len(members) != 1 else ''}"
            )
            # A subdirectory holding a single concept has no index (see
            # wants_index), so link straight to that concept.
            url = quote(name) + "/"
            if len(members) == 1 and members[0].rel.parent == directory / name:
                url += quote(members[0].rel.name)
            lines.append(entry(name, url, description))
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def wants_index(concepts: list[Concept], directory: PurePosixPath) -> bool:
    """An index exists for progressive disclosure, so a directory only gets one
    if it has something to disclose: it is the root, has subdirectories, or has
    two or more concepts. A lone concept is linked from its parent directly."""
    if directory == PurePosixPath("."):
        return True
    direct = [c for c in concepts if c.rel.parent == directory]
    nested = [c for c in concepts if c.rel.parent != directory and directory in c.rel.parents]
    return bool(nested) or len(direct) >= 2


def plan_indexes(bundle: Path, exclude: tuple[str, ...] = ()) -> dict[Path, str]:
    concepts = read_concepts(bundle, exclude)
    directories = {PurePosixPath(".")}
    for concept in concepts:
        directories.update(concept.rel.parents)
    return {
        bundle / d / "index.md": render_index(concepts, d)
        for d in sorted(directories)
        if wants_index(concepts, d)
    }


def stale_indexes(bundle: Path, exclude: tuple[str, ...] = ()) -> dict[Path, str]:
    stale = {}
    for path, content in plan_indexes(bundle, exclude).items():
        if not path.is_file() or path.read_text(encoding="utf-8") != content:
            stale[path] = content
    return stale


def update_log(bundle: Path, date: str, documents: int) -> bool:
    entry = (
        f"## {date}\n"
        f"* **Initialization**: Adopted Open Knowledge Format v{OKF_VERSION}: added "
        f"frontmatter to {documents} existing document{'s' if documents != 1 else ''} "
        "and generated `index.md` files with `okf`.\n"
    )
    log = bundle / "log.md"
    if not log.is_file():
        log.write_text(f"# Update Log\n\n{entry}", encoding="utf-8")
        return True
    existing = log.read_text(encoding="utf-8")
    head, _, rest = existing.partition("\n")
    log.write_text(f"{head}\n\n{entry}{rest}" if head.startswith("# ") else f"{entry}\n{existing}", encoding="utf-8")
    return True


# ── CLI ──────────────────────────────────────────────────────────────────────


def _bundles(args) -> list[Path]:
    bundles = [Path(b) for b in args.bundle]
    for bundle in bundles:
        if not bundle.is_dir():
            sys.exit(f"okf: {bundle} is not a directory")
    return bundles


def cmd_check(args) -> int:
    status = 0
    for bundle in _bundles(args):
        report = check_bundle(bundle, tuple(args.exclude))
        for finding in report.findings:
            print(f"{bundle}: {finding}")
        tiers = ", ".join(f"{n} {tier}" for tier, n in report.tiers.items() if n)
        print(
            f"{bundle}: {report.concepts} concepts, {len(report.errors)} errors, "
            f"{len(report.warnings)} warnings" + (f" ({tiers})" if tiers else "")
        )
        if report.errors or (args.strict and report.warnings):
            status = 1
    return status


def cmd_migrate(args) -> int:
    date = args.date or datetime.date.today().isoformat()
    for bundle in _bundles(args):
        exclude = tuple(args.exclude)
        changes = plan_migration(bundle, exclude)
        for change in changes:
            summary = change.meta.get("type", "")
            print(f"{'wrote' if args.write else 'would add'} frontmatter: "
                  f"{change.path.relative_to(bundle).as_posix()} [{summary}]")
        if args.write:
            for change in changes:
                change.path.write_text(change.text, encoding="utf-8", newline="")
            for path, content in plan_indexes(bundle, exclude).items():
                path.write_text(content, encoding="utf-8")
            if changes:
                update_log(bundle, date, len(changes))
        print(f"{bundle}: {len(changes)} documents {'migrated' if args.write else 'to migrate'}")
    return 0


def cmd_index(args) -> int:
    status = 0
    for bundle in _bundles(args):
        stale = stale_indexes(bundle, tuple(args.exclude))
        for path, content in stale.items():
            if args.write:
                path.write_text(content, encoding="utf-8")
                print(f"wrote {path}")
            else:
                print(f"stale: {path} (run: okf index --write {bundle})")
        if stale and not args.write:
            status = 1
    return status


def _site_module():
    try:
        import okf_site
    except ImportError as err:
        sys.exit(
            f"okf: `okf site` needs markdown-it-py, mdit-py-plugins and pygments ({err}). "
            "Use the Nix package, which provides them."
        )
    return okf_site


def cmd_site_build(args) -> int:
    okf_site = _site_module()
    try:
        site = okf_site.Site(
            _bundles(args), args.title, args.subtitle, tuple(args.exclude), start=args.start, theme=args.theme, mermaid=args.mermaid
        )
        summary = site.build(Path(args.out))
    except ValueError as err:
        sys.exit(f"okf: {err}")
    print(f"{args.out}: {summary['pages']} pages, {summary['assets']} assets")
    for problem in summary["problems"]:
        print(f"error: {problem}")
    return 1 if summary["problems"] else 0


def cmd_site_verify(args) -> int:
    problems = _site_module().verify_site(Path(args.site))
    for problem in problems:
        print(f"error: {problem}")
    print(f"{args.site}: {len(problems)} broken local references")
    return 1 if problems else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="okf", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p):
        p.add_argument("bundle", nargs="+", help="bundle root directory")
        p.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                       help="bundle-relative path glob to skip (repeatable)")

    check = sub.add_parser("check", help="validate bundles against OKF v0.2")
    common(check)
    check.add_argument("--strict", action="store_true", help="fail on warnings too")
    check.set_defaults(func=cmd_check)

    migrate = sub.add_parser("migrate", help="add frontmatter to markdown files without it")
    common(migrate)
    migrate.add_argument("--write", action="store_true", help="apply (default: dry run)")
    migrate.add_argument("--date", help="log.md date, YYYY-MM-DD (default: today)")
    migrate.set_defaults(func=cmd_migrate)

    index = sub.add_parser("index", help="generate index.md files")
    common(index)
    index.add_argument("--write", action="store_true", help="apply (default: report stale indexes)")
    index.set_defaults(func=cmd_index)

    site = sub.add_parser("site", help="render bundles as a static website")
    site_sub = site.add_subparsers(dest="site_command", required=True)
    build = site_sub.add_parser("build", help="write the website to --out")
    common(build)
    build.add_argument("--out", required=True, metavar="DIR", help="output directory")
    build.add_argument("--title", default="Knowledge", help="site title")
    build.add_argument("--subtitle", default="Notes, runbooks and reference, read from their source files.",
                       help="one line under the title on the landing page")
    build.add_argument("--start", metavar="BUNDLE/PATH.md",
                        help="a document the landing page points new readers to, e.g. docs/OKF.md")
    build.add_argument("--theme", choices=("field-manual", "trail-map", "manpage", "lantern", "toc", "okf-visualizer", "okf-visualizer-dark"),
                       default="field-manual", help="default colour and type treatment")
    build.add_argument("--mermaid", metavar="FILE", help="local mermaid.min.js to render mermaid fences offline")
    build.set_defaults(func=cmd_site_build)
    verify = site_sub.add_parser("verify", help="check every local link in a built site")
    verify.add_argument("site", metavar="DIR")
    verify.set_defaults(func=cmd_site_verify)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
