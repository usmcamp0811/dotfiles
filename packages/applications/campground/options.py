"""Turn nixosOptionsDoc JSON into a build-generated OKF bundle."""
import json
import os
import sys
from pathlib import Path
from urllib.parse import quote

import yaml


def generate(source, output, repository=None):
    options = json.loads(Path(source).read_text())
    root = Path(output) / "options"
    root.mkdir(parents=True)
    groups = {}
    for name, option in sorted(options.items()):
        parts = option.get("loc", name.split("."))
        group = ".".join(parts[:3])
        groups.setdefault(group, []).append((name, option))
    for group, members in groups.items():
        path = root.joinpath(*group.split(".")).with_suffix(".md")
        path.parent.mkdir(parents=True, exist_ok=True)
        meta = {
            "type": "NixOS Options",
            "title": group,
            "description": f"Evaluated option reference for {group} ({len(members)} options).",
            "tags": ["nixos", "options"],
        }
        lines = ["---\n" + yaml.safe_dump(meta, sort_keys=False) + "---\n", f"# {group}\n"]
        lines.append("Generated from module declarations, not a host configuration. Defaults and examples are omitted because some require host-specific or Vault configuration. The unfinished RMF example module is excluded because it redeclares an existing option.\n")
        guides = set()
        for _, option in members:
            for declaration in option.get("declarations", []):
                guide = Path(declaration).parent / "README.md"
                if repository and (Path(repository) / guide).is_file():
                    guides.add(guide.as_posix())
        for guide in sorted(guides):
            # Both the authored bundles and this generated bundle share a root.
            relative = os.path.relpath(Path(output) / guide, path.parent)
            lines.append(f"[Module guide]({quote(relative)})\n")
        for name, option in members:
            lines.extend([f"## `{name}`\n", option.get("description") or "No description provided by this module.", f"\n**Type:** {option.get('type', 'unspecified')}\n"])
            declarations = option.get("declarations", [])
            if declarations:
                lines.append("**Declared in:** " + ", ".join(f"`{p}`" for p in declarations) + "\n")
        path.write_text("\n".join(lines))


if __name__ == "__main__":
    generate(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
