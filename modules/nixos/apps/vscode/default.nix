{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.vscode;
in
{
  options.campground.apps.vscode = with types; {
    enable = mkBoolOpt false "Whether or not to enable vscode.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ vscode ]; };
}
