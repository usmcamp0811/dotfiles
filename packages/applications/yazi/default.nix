{ lib
, pkgs
, inputs
, makeWrapper
, stdenv
, ...
}:
with lib;
with lib.fmf;
let
  # Create a wrapped yazi with all plugins and config
  campground-yazi = stdenv.mkDerivation {
    name = "campground-yazi";

    dontUnpack = true;
    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      # Create directory structure
      mkdir -p $out/bin
      mkdir -p $out/share/yazi/config
      mkdir -p $out/share/yazi/plugins

      # Copy init.lua
      cp ${./init.lua} $out/share/yazi/config/init.lua

      # Link all plugins
      ln -sf ${pkgs.yaziPlugins.chmod} $out/share/yazi/plugins/chmod.yazi
      ln -sf ${pkgs.yaziPlugins.diff} $out/share/yazi/plugins/diff.yazi
      ln -sf ${pkgs.yaziPlugins.full-border} $out/share/yazi/plugins/full-border.yazi
      ln -sf ${pkgs.yaziPlugins.git} $out/share/yazi/plugins/git.yazi
      ln -sf ${pkgs.yaziPlugins.toggle-pane} $out/share/yazi/plugins/toggle-pane.yazi
      ln -sf ${pkgs.yaziPlugins.mount} $out/share/yazi/plugins/mount.yazi
      ln -sf ${pkgs.yaziPlugins.smart-enter} $out/share/yazi/plugins/smart-enter.yazi
      ln -sf ${pkgs.yaziPlugins.vcs-files} $out/share/yazi/plugins/vcs-files.yazi
      ln -sf ${inputs.office-yazi} $out/share/yazi/plugins/office.yazi
      ln -sf ${pkgs.yaziPlugins.rich-preview} $out/share/yazi/plugins/rich-preview.yazi
      ln -sf ${inputs.eza-preview-yazi} $out/share/yazi/plugins/eza-preview.yazi
      ln -sf ${pkgs.yaziPlugins.mediainfo} $out/share/yazi/plugins/mediainfo.yazi
      ln -sf ${inputs.fzf-yazi} $out/share/yazi/plugins/fg.yazi
      ln -sf ${pkgs.yaziPlugins.glow} $out/share/yazi/plugins/glow.yazi
      ln -sf ${inputs.hexyl-yazi} $out/share/yazi/plugins/hexyl.yazi
      ln -sf ${pkgs.yaziPlugins.ouch} $out/share/yazi/plugins/ouch.yazi
      ln -sf ${pkgs.yaziPlugins.yatline} $out/share/yazi/plugins/yatline.yazi
      ln -sf ${pkgs.yaziPlugins.yatline-catppuccin} $out/share/yazi/plugins/yatline-catppuccin.yazi
      ln -sf ${pkgs.yaziPlugins.lazygit} $out/share/yazi/plugins/lazygit.yazi
      ln -sf ${inputs.githead-yazi} $out/share/yazi/plugins/githead.yazi
      ln -sf ${pkgs.yaziPlugins.duckdb} $out/share/yazi/plugins/duckdb.yazi
      ln -sf ${inputs.bunny-yazi} $out/share/yazi/plugins/bunny.yazi

      # Wrap the yazi binary to use our config
      makeWrapper ${pkgs.yazi}/bin/yazi $out/bin/yazi \
        --set YAZI_CONFIG_HOME "$out/share/yazi/config" \
        --prefix PATH : ${lib.makeBinPath [
          pkgs.mediainfo
          pkgs.rich-cli
          pkgs.ouch
          pkgs.glow
          pkgs.hexyl
          pkgs.fzf
          pkgs.eza
          pkgs.duckdb
        ]}
    '';

    meta = with lib; {
      description = "Campground customized yazi file manager - portable version";
      homepage = "https://yazi-rs.github.io";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "yazi";
    };
  };
in
campground-yazi
