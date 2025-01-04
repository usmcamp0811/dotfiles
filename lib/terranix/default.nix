{ lib, inputs, ... }:
with lib; rec {
  # Recursively scans a directory and loads all `default.nix` files found.
  #
  # @param path The base directory to scan for `default.nix` files.
  #
  # @return A list of file paths to all `default.nix` files found within the given directory and its subdirectories.
  #
  # The function operates by:
  # - Reading the directory specified by `path`.
  # - Filtering for files named `default.nix` based on the pattern `.*default\.nix$`.
  # - Recursively scanning subdirectories to find additional `default.nix` files.
  # - Combining all paths into a single list.
  #
  # Example:
  # ```nix
  # findDefaultNixFiles ./modules
  # ```
  # This will return a list of paths to all `default.nix` files in the `modules` directory and its subdirectories.
  findDefaultNixFiles = path:
    let
      scanDir = dir:
        let
          entries = builtins.readDir dir;
          files = builtins.filter
            (name:
              let entry = entries.${name};
              in entry == "regular" && builtins.match ".*default\\.nix$" name
                != null)
            (builtins.attrNames entries);
          filePaths = builtins.map (file: "${dir}/${file}") files;
          subDirs = builtins.filter
            (name: let entry = entries.${name}; in entry == "directory")
            (builtins.attrNames entries);
          subDirPaths = builtins.concatLists
            (builtins.map (subDir: scanDir "${dir}/${subDir}") subDirs);
        in
        filePaths ++ subDirPaths;
    in
    scanDir path;

  terranixConfiguration = { system, extraArgs ? { }, modules }:
    inputs.terranix.lib.terranixConfiguration {
      inherit system;
      extraArgs = { inherit lib; } // extraArgs;
      modules = findDefaultNixFiles ../../modules ++ modules;
    };
}
