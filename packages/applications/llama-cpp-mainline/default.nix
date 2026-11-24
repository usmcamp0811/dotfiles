# A second, newer upstream llama.cpp, pinned by release tag. The default runtime (`pkgs.llama-cpp`, nixpkgs'
# b9190) stays as it is and keeps serving the existing catalog; this one exists because two things need
# more than b9190 has:
#   * Ternary-Bonsai-2-27B `Q2_0` needs the Hadamard activation runtime, upstream from b11556. An older
#     build loads the file WITHOUT any warning and produces garbage.
#   * Inkling 2 Mini (`inkling2_loop`) landed upstream after b12600; ggml-org's own GGUFs are reported
#     against b12600 to b12620 in ggml-org/llama.cpp#32710 and #32778 (known bugs, see the llama-cpp module
#     README). Do not go below b12619.
# Overrides the nixpkgs derivation (same build flags; `cudaSupport` follows the caller) so only the source
# differs. The embedded web UI is not built: an API server does not need it, and it would add a second,
# separately hashed npm closure that b12651's tree no longer has (tools/ui is gone).
# Bump: `nix flake prefetch --json github:ggml-org/llama.cpp/b<version>` gives the hash.
{
  pkgs,
  lib,
  ...
}:
pkgs.llama-cpp.overrideAttrs (final: old: {
  pname = "llama-cpp-mainline";
  version = "12651";
  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "b${final.version}";
    hash = "sha256-GNdA6CFxrkFNSocjHhZT2ML53WkdvTSQBMieitPR1ts=";
  };
  nativeBuildInputs = lib.filter (p: !(lib.hasPrefix "npm-config-hook" (p.name or ""))) old.nativeBuildInputs;
  npmDeps = null;
  # nixpkgs derives COMMIT from .git (and runs the UI build); the tarball has no .git.
  preConfigure = ''
    prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=f5e6915"
  '';
  meta = old.meta // {
    description = "llama.cpp b12651 (second upstream runtime for Inkling 2 and Bonsai Q2_0)";
    homepage = "https://github.com/ggml-org/llama.cpp/releases/tag/b12651";
  };
})
