{ inputs
, options
, config
, pkgs
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg-user = config.fmf.user;
  is-darwin = pkgs.stdenv.isDarwin;

  # aliases = import ./aliases.nix { inherit pkgs; };
  home-directory =
    if cfg-user.name == null
    then null
    else if is-darwin
    then "/Users/${cfg-user.name}"
    else "/home/${cfg-user.name}";
in
{
  options.fmf.cli.env = with types;
    mkOption {
      type = attrsOf (oneOf [ str path (listOf (either str path)) ]);
      apply = mapAttrs (_n: v:
        if isList v
        then concatMapStringsSep ":" (x: toString x) v
        else (toString v));
      default = { };
      description = "A set of environment variables to set.";
    };

  config = {
    home.sessionVariables = {
      NIXOS_CONFIG = "/config";
      KUBECONFIG = "/etc/k8s/config";
      EDITOR = "${pkgs.campground-nvim}/bin/nvim";
      TERMINAL = "kitty";
      # BROWSER = "firefox";
      BROWSER = "brave";
      READER = "${pkgs.zathura}/bin/zathura";
      XDG_CONFIG_HOME = "${home-directory}/.config";
      DOCKER = "/var/run/docker.sock";
      DOCKER_CONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/docker";
      XDG_DATA_HOME = "${home-directory}/.local/share";
      XDG_BIN_HOME = mkDefault "$HOME/.local/bin";
      TMUX_TMPDIR = "$XDG_RUNTIME_DIR";
      NODE_REPL_HISTORY = "${config.home.sessionVariables.XDG_DATA_HOME}/node_repl_history";
      NVM_DIR = "${config.home.sessionVariables.XDG_DATA_HOME}/nvm";
      PYLINTHOME = "$XDG_CACHE_HOME/pylint";
      XDG_CACHE_HOME = mkDefault "$HOME/.cache";
      PYTHON_EGG_CACHE = "${config.home.sessionVariables.XDG_CACHE_HOME}/python-eggs";
      WGETRC = "${config.home.sessionVariables.XDG_CONFIG_HOME}/wgetrc";
      CARGO_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/cargo";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      IPYTHONDIR = "${config.home.sessionVariables.XDG_CONFIG_HOME}/jupyter";
      JUPYTER_CONFIG_DIR = "${config.home.sessionVariables.XDG_CONFIG_HOME}/jupyter";
      GOPATH = "${config.home.sessionVariables.XDG_DATA_HOME}/go";
      JULIA_EDITOR = "nvim";
      JULIA_NUM_THREADS = "12";
      JULIA_LOAD_PATH = "${config.home.sessionVariables.XDG_CONFIG_HOME}/julia:$julia_load_path";
      JULIA_DEPOT_PATH = "${config.home.sessionVariables.XDG_CONFIG_HOME}/julia:$julia_depot_path";
      SSB_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/zoom";
      POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD = "true";
      CONDARC = "${config.home.sessionVariables.XDG_CONFIG_HOME}/conda/condarc";
    };
    home.activation.privateDir = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.config/shell/private/"
    '';
  };
}
