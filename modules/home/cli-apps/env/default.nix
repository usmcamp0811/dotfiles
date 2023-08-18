{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.env;
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

    home.sessionvariables = {
      kubeconfig = "/etc/k8s/config";
      editor = "nvim";
      terminal = "kitty";
      browser = "qutebrowser";
      reader = "zathura";
      xdg_config_home = "${config.home.homedirectory}/.config";
      docker = "/var/run/docker.sock";
      docker_config = "${config.home.sessionvariables.xdg_config_home}/docker";
      xdg_data_home = "${config.home.homedirectory}/.local/share";
      tmux_tmpdir = "$xdg_runtime_dir";
      node_repl_history = "${config.home.sessionvariables.xdg_data_home}/node_repl_history";
      nvm_dir = "${config.home.sessionvariables.xdg_data_home}/nvm";
      pylinthome = "$xdg_cache_home/pylint";
      python_egg_cache = "$xdg_cache_home/python-eggs";
      wgetrc = "${config.home.sessionvariables.xdg_config_home}/wgetrc";
      cargo_home = "${config.home.sessionvariables.xdg_data_home}/cargo";
      manpager = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      ipythondir = "${config.home.sessionvariables.xdg_config_home}/jupyter";
      jupyter_config_dir = "${config.home.sessionvariables.xdg_config_home}/jupyter";
      gopath = "${config.home.sessionvariables.xdg_data_home}/go";
      julia_editor = "nvim";
      julia_num_threads = "12";
      julia_load_path = "${config.home.sessionvariables.xdg_config_home}/julia:$julia_load_path";
      julia_depot_path = "${config.home.sessionvariables.xdg_config_home}/julia:$julia_depot_path";
      ssb_home = "${config.home.sessionvariables.xdg_data_home}/zoom";
      condarc = "${config.home.sessionvariables.xdg_config_home}/conda/condarc";
    };
    home.extraInit = concatStringsSep "\n"
        (mapAttrsToList (n: v: ''export ${n}="${v}"'') cfg);
    };
  };
}
