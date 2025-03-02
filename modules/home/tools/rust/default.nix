{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.rust;
in {
  options.campground.tools.rust = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Rust.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      cargo
      evcxr
      rust-analyzer
      rustfmt
      clippy
      rustc
      dioxus-cli
      wasm-bindgen-cli
      lld
      rustlings
    ];
  };
}
