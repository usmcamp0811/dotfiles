{
  inputs,
  lib,
  ...
}: final: prev: {
  yaziPlugins = prev.yaziPlugins // {
    # Override the yatline-githead plugin to fix deprecated API calls
    yatline-githead = prev.yaziPlugins.yatline-githead.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        # Fix deprecated ya.render() -> ui.render()
        substituteInPlace main.lua \
          --replace-fail "ya.render()" "ui.render()"
      '';
    });
  };
}
