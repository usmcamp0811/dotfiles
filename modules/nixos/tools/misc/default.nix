{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.tools.misc;
  # flake-src = ../../../..;

  # dynamicValue =
  #   pkgs.runCommand "get-sys-configs" { buildInputs = [ pkgs.nix ]; } ''
  #     set -e  # Stop on errors
  #     nix repl 2>/dev/null <<EOF > $out || (echo "Error in nix repl execution" > $out && exit 0)
  #       :lf ${toString flake-src}
  #       sys = lib.findVaultPathsAndFields outputs.nixosConfigurations.butler.config.campground
  #       builtins.toJSON sys
  #     EOF
  #   '';
  # dynamicValueText = builtins.readFile dynamicValue;
in
{
  options.campground.tools.misc = with types; {
    enable = mkBoolOpt false "Whether or not to enable common utilities.";
  };

  config = mkIf cfg.enable {
    campground.home.configFile."wgetrc".text = "";
    # campground.home.configFile."tst.json".text = dynamicValueText;

    environment.systemPackages = with pkgs; [
      fzf
      killall
      unzip
      file
      jq
      clac
      wget
      ripgrep
      bat
      ranger
      lsd
      git
      rsync
      tldr
      gcc
      clang
      zig
      btop
      deno
      flameshot
      neovim
      devour
      usbutils
      pciutils
      neofetch
      libnotify
      sbomnix
      bash
      lsof
      hwinfo
      traceroute
      gptfdisk
      parted
      tmux
      cntr
      glibc
      smartmontools
      lshw
      borgbackup
      yt-dlp
    ];
  };
}
