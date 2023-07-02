{
  description = "Matt Camp";
  username = "mcamp";
  homeDirectory = "/home/mcamp";
  stateVersion = "23.05";
  isNormalUser = true;
  extraGroups = ["docker" "networkmanager" "wheel" ];
  shell = pkgs.zsh;
}

