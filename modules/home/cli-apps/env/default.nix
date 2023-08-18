{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.cli-apps.env;
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
  options.campground.cli-apps.env = with types;
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
      kubeconfig = "/etc/k8s/config";
      editor = "nvim";
      terminal = "kitty";
      browser = "qutebrowser";
      reader = "zathura";
      xdg_config_home = "${home-directory}/.config";
      docker = "/var/run/docker.sock";
      docker_config = "${config.home.sessionVariables.xdg_config_home}/docker";
      xdg_data_home = "${home-directory}/.local/share";
      tmux_tmpdir = "$xdg_runtime_dir";
      node_repl_history = "${config.home.sessionVariables.xdg_data_home}/node_repl_history";
      nvm_dir = "${config.home.sessionVariables.xdg_data_home}/nvm";
      pylinthome = "$xdg_cache_home/pylint";
      python_egg_cache = "$xdg_cache_home/python-eggs";
      wgetrc = "${config.home.sessionVariables.xdg_config_home}/wgetrc";
      cargo_home = "${config.home.sessionVariables.xdg_data_home}/cargo";
      manpager = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      ipythondir = "${config.home.sessionVariables.xdg_config_home}/jupyter";
      jupyter_config_dir = "${config.home.sessionVariables.xdg_config_home}/jupyter";
      gopath = "${config.home.sessionVariables.xdg_data_home}/go";
      julia_editor = "nvim";
      julia_num_threads = "12";
      julia_load_path = "${config.home.sessionVariables.xdg_config_home}/julia:$julia_load_path";
      julia_depot_path = "${config.home.sessionVariables.xdg_config_home}/julia:$julia_depot_path";
      ssb_home = "${config.home.sessionVariables.xdg_data_home}/zoom";
      condarc = "${config.home.sessionVariables.xdg_config_home}/conda/condarc";
    };
    # programs.zsh.extraInit = concatStringsSep "\n"
    #     (mapAttrsToList (n: v: ''export ${n}="${v}"'') cfg);
    };
}
