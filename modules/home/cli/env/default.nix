{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.cli.env;
  cfg-user = config.campground.user;

  is-linux = pkgs.stdenv.isLinux;
  is-darwin = pkgs.stdenv.isDarwin;

  home-directory =
    if cfg-user.name == null then
      null
    else if is-darwin then
      "/Users/${cfg-user.name}"
    else
      "/home/${cfg-user.name}";
in
{
  options.campground.cli.env = with types;
    mkOption {
      type = attrsOf (oneOf [ str path (listOf (either str path)) ]);
      apply = mapAttrs (n: v:
        if isList v then
          concatMapStringsSep ":" (x: toString x) v
        else
          (toString v));
      default = { };
      description = "A set of environment variables to set.";
    };

  config = {

    home.sessionVariables = {
      KUBECONFIG = "/etc/k8s/config";
      EDITOR = "nvim";
      TERMINAL = "kitty";
      BROWSER = "qutebrowser";
      READER = "zathura";
      XDG_CONFIG_HOME = "${home-directory}/.config";
      DOCKER = "/var/run/docker.sock";
      DOCKER_CONFIG = "${config.home.sessionVariables.xdg_config_home}/docker";
      XDG_DATA_HOME = "${home-directory}/.local/share";
      TMUX_TMPDIR = "$xdg_runtime_dir";
      NODE_REPL_HISTORY = "${config.home.sessionVariables.xdg_data_home}/node_repl_history";
      NVM_DIR = "${config.home.sessionVariables.xdg_data_home}/nvm";
      PYLINTHOME = "$xdg_cache_home/pylint";
      PYTHON_EGG_CACHE = "$xdg_cache_home/python-eggs";
      WGETRC = "${config.home.sessionVariables.xdg_config_home}/wgetrc";
      CARGO_HOME = "${config.home.sessionVariables.xdg_data_home}/cargo";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      IPYTHONDIR = "${config.home.sessionVariables.xdg_config_home}/jupyter";
      JUPYTER_CONFIG_DIR = "${config.home.sessionVariables.xdg_config_home}/jupyter";
      GOPATH = "${config.home.sessionVariables.xdg_data_home}/go";
      JULIA_EDITOR = "nvim";
      JULIA_NUM_THREADS = "12";
      JULIA_LOAD_PATH = "${config.home.sessionVariables.xdg_config_home}/julia:$julia_load_path";
      JULIA_DEPOT_PATH = "${config.home.sessionVariables.xdg_config_home}/julia:$julia_depot_path";
      SSB_HOME = "${config.home.sessionVariables.xdg_data_home}/zoom";
      CONDARC = "${config.home.sessionVariables.xdg_config_home}/conda/condarc";
    };
    # programs.zsh.extraInit = concatStringsSep "\n"
    #     (mapAttrsToList (n: v: ''export ${n}="${v}"'') cfg);

    # aliases are in a seperate file because we can't do shell functions in Nix
    home.file = { 
      ".config/shell/aliases.shrc".source = ./aliases.shrc;
    };
  };
}
