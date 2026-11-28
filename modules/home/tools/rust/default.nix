{ config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.tools.rust;
in {
  options.fmf.tools.rust = with types; {
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
      # deno also ships a `dx` binary; hiPrio makes dioxus-cli's win in the profile without
      # rebuilding deno (overriding deno meant compiling it from source).
      (lib.hiPrio dioxus-cli)
      wasm-bindgen-cli
      lld
      rustlings
    ];
  };
}
