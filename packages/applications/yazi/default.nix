{ lib
, pkgs
, inputs
, ...
}:
with lib;
with lib.fmf;
let
  # Patch the githead plugin to fix deprecated API
  githead-patched = pkgs.stdenv.mkDerivation {
    name = "githead-yazi-patched";
    src = inputs.githead-yazi;

    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out/

      # Fix deprecated ya.render() -> ui.render()
      substituteInPlace $out/main.lua \
        --replace-fail "ya.render()" "ui.render()"
    '';
  };

  # Patch the yatline plugin to fix deprecated API
  yatline-patched = pkgs.yaziPlugins.yatline.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Fix any deprecated ya.truncate() -> ui.truncate()
      find . -name "*.lua" -type f -exec sed -i 's/ya\.truncate(/ui.truncate(/g' {} +
    '';
  });

  # Create custom yazi package with all the configs
  campground-yazi = pkgs.symlinkJoin {
    name = "campground-yazi";
    paths = [ pkgs.yazi ];
    buildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Create config directory structure
      mkdir -p $out/share/yazi

      # Copy init.lua
      cp ${./init.lua} $out/share/yazi/init.lua

      # Create plugins directory
      mkdir -p $out/share/yazi/plugins

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
      ln -sf ${yatline-patched} $out/share/yazi/plugins/yatline.yazi
      ln -sf ${pkgs.yaziPlugins.yatline-catppuccin} $out/share/yazi/plugins/yatline-catppuccin.yazi
      ln -sf ${pkgs.yaziPlugins.lazygit} $out/share/yazi/plugins/lazygit.yazi
      ln -sf ${githead-patched} $out/share/yazi/plugins/githead.yazi
      ln -sf ${pkgs.yaziPlugins.duckdb} $out/share/yazi/plugins/duckdb.yazi
      ln -sf ${inputs.bunny-yazi} $out/share/yazi/plugins/bunny.yazi

      # Wrap the yazi binary to use our config
      wrapProgram $out/bin/yazi \
        --set YAZI_CONFIG_HOME "$out/share/yazi"
    '';

    meta = with lib; {
      description = "Campground customized yazi file manager";
      homepage = "https://yazi-rs.github.io";
      platforms = platforms.unix;
    };
  };
in
campground-yazi
