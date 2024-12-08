{ pkgs, lib, ... }:
with lib;
with lib.campground;
let

  python-env =
    pkgs.python3.withPackages (ps: [ ps.pyyaml ps.deepdiff ps.configargparse ]);
  yaml-diff-analyzer-script = pkgs.writeText "yaml-diff-analyzer.py" ''
    import yaml
    import argparse
    from deepdiff import DeepDiff


    def load_yaml(file_path):
        with open(file_path, "r") as file:
            return yaml.safe_load(file)


    def unravel_path(path):
        """
        Converts DeepDiff path (tree view) to a list of keys that can be used to navigate a YAML structure.
        """
        if not path:
            return []
        keys = []
        for part in path:
            if isinstance(part, str) and part.isdigit():
                keys.append(int(part))  # Convert array indices to integers
            else:
                keys.append(part)
        return keys


    def get_env_var_value(env_vars, path):
        """
        Navigates the env-vars.yaml structure to retrieve the value based on the unraveled path.
        """
        keys = unravel_path(path)
        value = env_vars
        try:
            for key in keys:
                value = value[key]
            return value
        except (KeyError, IndexError, TypeError):
            return "Not Found"


    def compare_yaml(file1, file2, env_file=None):
        yaml1 = load_yaml(file1)
        yaml2 = load_yaml(file2)
        env_vars = load_yaml(env_file) if env_file else {}

        diff = DeepDiff(yaml1, yaml2, ignore_order=True, view="tree")
        if not diff:
            print("The YAML files are equivalent.")
        else:
            print("Differences found:")
            formatted_diff = []
            for diff_type, changes in diff.items():
                for change in changes:
                    path = change.path(
                        output_format="list"
                    )  # Use list format for traversing
                    diff_entry = {
                        "path": ".".join(map(str, path)),  # Reconstruct path as a string
                        "file1": change.t1,
                        "file2": change.t2,
                    }
                    if env_file:  # Add env_var_value only if env-vars.yaml is provided
                        diff_entry["env_var_value"] = get_env_var_value(env_vars, path)
                    formatted_diff.append(diff_entry)
            print(yaml.dump(formatted_diff, default_flow_style=False, sort_keys=False))


    def main():
        parser = argparse.ArgumentParser(
            description="Compare two YAML files and optionally lookup values in a third YAML file."
        )
        parser.add_argument("file1", help="Path to the first YAML file.")
        parser.add_argument("file2", help="Path to the second YAML file.")
        parser.add_argument(
            "--env-file",
            help="Path to the optional third YAML file for value lookups.",
            default=None,
        )

        args = parser.parse_args()

        compare_yaml(args.file1, args.file2, args.env_file)


    if __name__ == "__main__":
        main()
  '';

in
pkgs.writeShellApplication {
  name = "yaml-diff-analyzer";
  text = ''
    ${python-env}/bin/python ${yaml-diff-analyzer-script} "$@"
  '';
}
