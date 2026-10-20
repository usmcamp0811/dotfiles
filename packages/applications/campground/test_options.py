import json
import tempfile
import unittest
from pathlib import Path

from options import generate


class OptionsTest(unittest.TestCase):
    def test_groups_options_and_links_authored_guide(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            guide = root / "modules/nixos/services/example/README.md"
            guide.parent.mkdir(parents=True)
            guide.write_text("# Example\n")
            source = root / "options.json"
            source.write_text(json.dumps({
                "fmf.services.example.enable": {
                    "loc": ["fmf", "services", "example", "enable"],
                    "type": "boolean",
                    "description": "Enable the example service.",
                    "declarations": ["modules/nixos/services/example/default.nix"],
                },
                "fmf.services.example.port": {
                    "loc": ["fmf", "services", "example", "port"],
                    "type": "port",
                },
            }))
            output = root / "generated"
            generate(source, output, root)
            page = output / "options/fmf/services/example.md"
            text = page.read_text()
            self.assertIn("## `fmf.services.example.enable`", text)
            self.assertIn("## `fmf.services.example.port`", text)
            self.assertIn("**Type:** boolean", text)
            self.assertIn("No description provided", text)
            self.assertIn("../../../modules/nixos/services/example/README.md", text)
            self.assertNotIn("verified:", text)


if __name__ == "__main__":
    unittest.main()
