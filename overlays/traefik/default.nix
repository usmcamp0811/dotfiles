# See https://github.com/NixOS/nixpkgs/issues/265496
{ nixpkgs, ... }:

let plugins = builtins.fromJSON (builtins.readFile ./plugins.json);
in
with nixpkgs.lib;
(final: prev: {
  traefik-custom = prev.traefik.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + strings.concatMapStrings
      (plugin:
        let site = plugin.site or "github.com";
        in with plugin; ''
        mkdir -p $out/bin/plugins-local/src/${site}/${owner}/
        cp -r ${ pkgs.fetchFromGitHub { inherit owner repo rev sha256; } } $out/bin/plugins-local/src/${site}/${owner}/${repo}
      '')
      plugins;
  });
})
