{
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    dataPath = { __raw = "vim.fn.stdpath('data')"; };
    detectionMethods = [ "lsp" "pattern" ];
    patterns = [
      ".git"
      "_darcs"
      ".hg"
      ".bzr"
      ".svn"
      "Makefile"
      "package.json"
      "deps.edn"
      "Project.toml"
      "pyproject.toml"
      "setup.py"
      "requirements.txt"
      "flake.lock"
      "flake.nix"
    ];
    showHidden = true;
    silentChdir = true;
    extraOptions = {
      active = true;
      manual_mode = false;
    };
  };
}
