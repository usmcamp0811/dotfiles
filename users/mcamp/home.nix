{ config, lib, pkgs, ... }:

{
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";
  home.stateVersion = "22.11";

  nixpkgs.config.allowUnfree = true;

  imports = [
    ./apps/brave.nix
    ./apps/firefox.nix
  ];

  home.packages = with pkgs; [
    k9s
    btop
    julia
    deno
    autorandr
    arandr
    qutebrowser
    zathura
    xclip
    xsel
  ];

  services = {
    syncthing = {
      enable = true;
    };
  };

  xsession.windowManager.command = ''
    ${pkgs.dunst}/bin/dunst &
    ${config.xsession.windowManager.command}
    ${pkgs.ckb-next}/bin/ckb-next -b &
    ${pkgs.go-sct}/bin/sct &
    ${pkgs.feh}/bin/feh --bg-scale ${config.home.homeDirectory}/.background
  '';

  home.file = { 
    ".background".source = ./files/.background;
    ".config/shell/aliases.shrc".source = ./files/shell/aliases.shrc;
    ".config/shell/zsh/00-main.zsh".source = ./files/shell/zsh/00-main.zsh;
    ".config/shell/zsh/fino.zsh-theme".source = ./files/shell/zsh/fino.zsh-theme;
    ".config/shell/zsh/git.zsh".source = ./files/shell/zsh/git.zsh;
    ".config/shell/zsh/prompt_info_functions.zsh".source = ./files/shell/zsh/prompt_info_functions.zsh;
    ".config/shell/zsh/spectrum.zsh".source = ./files/shell/zsh/spectrum.zsh;
    ".config/shell/zsh/theme-and-appearance.zsh".source = ./files/shell/zsh/theme-and-appearance.zsh;
  };

  programs.zsh = {
    enable = true;
    initExtra = ''
      source $HOME/.config/shell/zsh/fino.zsh-theme
      source $HOME/.config/shell/aliases.shrc
      [ -r "/var/lib/vault/users/mcamp/passwords" ] && source "/var/lib/vault/users/mcamp/passwords"
      bindkey -v
    '';
  };

  home.sessionVariables = {
    KUBECONFIG = "/etc/k8s/config";
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "qutebrowser";
    READER = "zathura";
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    DOCKER = "/var/run/docker.sock";
    DOCKER_CONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/docker";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    TMUX_TMPDIR = "$XDG_RUNTIME_DIR";
    NODE_REPL_HISTORY = "${config.home.sessionVariables.XDG_DATA_HOME}/node_repl_history";
    NVM_DIR = "${config.home.sessionVariables.XDG_DATA_HOME}/nvm";
    PYLINTHOME = "$XDG_CACHE_HOME/pylint";
    PYTHON_EGG_CACHE = "$XDG_CACHE_HOME/python-eggs";
    WGETRC = "${config.home.sessionVariables.XDG_CONFIG_HOME}/wgetrc";
    CARGO_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/cargo";
    MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
    IPYTHONDIR = "${config.home.sessionVariables.XDG_CONFIG_HOME}/jupyter";
    JUPYTER_CONFIG_DIR = "${config.home.sessionVariables.XDG_CONFIG_HOME}/jupyter";
    GOPATH = "${config.home.sessionVariables.XDG_DATA_HOME}/go";
    JULIA_EDITOR = "nvim";
    JULIA_NUM_THREADS = "12";
    JULIA_LOAD_PATH = "${config.home.sessionVariables.XDG_CONFIG_HOME}/julia:$JULIA_LOAD_PATH";
    JULIA_DEPOT_PATH = "${config.home.sessionVariables.XDG_CONFIG_HOME}/julia:$JULIA_DEPOT_PATH";
    SSB_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/zoom";
    CONDARC = "${config.home.sessionVariables.XDG_CONFIG_HOME}/conda/condarc";
  };

  programs.home-manager.enable = true;

  home.activation = {
    copyMySSHKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
      cp /var/lib/vault/users/mcamp/id_ed25519 ${config.home.homeDirectory}/.ssh/id_ed25519
      chmod 600 ${config.home.homeDirectory}/.ssh/id_ed25519
      ${pkgs.openssh}/bin/ssh-keygen -y -f ${config.home.homeDirectory}/.ssh/id_ed25519 > ${config.home.homeDirectory}/.ssh/id_ed25519.pub
    '';
  };
}

