# PrismML's llama.cpp fork, pinned by commit. Needed for Ternary-Bonsai-2-27B `PTQ1_0` (dense trits, 5.95 GB)
# and `PQ2_0`: they are quantization types the fork adds, and stock llama.cpp rejects them as unknown. The
# fork also carries the ternary hybrid-attention CUDA kernels; the model card measures PTQ1_0 decode as the
# faster pack on Ada cards (RTX 4090: 91.1 tok/s against 81.2 for PQ2_0; PQ2_0 wins on prompt processing).
# The 4070 Ti SUPER is Ada too, but nothing has been measured on it yet.
#
# Separate from, and never a replacement for, `pkgs.llama-cpp` (nixpkgs) and `pkgs.fmf.llama-cpp-mainline`.
# `Q2_0` runs on stock llama.cpp b11556+; that is the fallback if this fork is dropped.
#
# Release prism-b12128-d7b2896 (2026-10-31, newest at the time). Bonsai-demo itself still pins the older
# prism-b10777-e3de715.
#   * CUDA comes from nixpkgs (12.x), not 13.3: the model's KNOWN_ISSUES.md lists CUDA 13.3 builds crashing
#     on some systems (PrismML-Eng/llama.cpp#222).
#   * Architectures are pinned to Ada (8.9): the fork's CMake can fail with "CUDA_ARCHITECTURES is empty"
#     (#182) and it is the only GPU here. Pass `cudaArchitectures` for another card.
# The embedded web UI is not built (API server only; no npm closure to hash).
# Bump: `nix flake prefetch --json github:PrismML-Eng/llama.cpp/<rev>` gives the hash.
{
  pkgs,
  lib,
  cudaArchitectures ? "89-real",
  ...
}: let
  rev = "d7b28968306207fd176e7ff10796ccb6be607865";
in
  pkgs.llama-cpp.overrideAttrs (final: old: {
    pname = "llama-cpp-prism";
    version = "12128";
    src = pkgs.fetchFromGitHub {
      owner = "PrismML-Eng";
      repo = "llama.cpp";
      inherit rev;
      hash = "sha256-uG0p3hztns+OVLXEvnKnVdU/9b2g02hWs58dWVVtVaQ=";
    };
    nativeBuildInputs = lib.filter (p: !(lib.hasPrefix "npm-config-hook" (p.name or ""))) old.nativeBuildInputs;
    npmDeps = null;
    preConfigure = ''
      prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=${builtins.substring 0 7 rev}"
    '';
    # Later -D wins in CMake: replaces the architecture list nixpkgs adds when cudaSupport is on (harmless otherwise).
    cmakeFlags = (old.cmakeFlags or []) ++ ["-DCMAKE_CUDA_ARCHITECTURES=${cudaArchitectures}"];
    meta = old.meta // {
      description = "PrismML llama.cpp fork (prism-b12128-d7b2896): ternary PTQ1_0/PQ2_0 kernels for Bonsai";
      homepage = "https://github.com/PrismML-Eng/llama.cpp";
    };
  })
