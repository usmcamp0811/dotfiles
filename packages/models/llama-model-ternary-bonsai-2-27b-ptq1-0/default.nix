{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Ternary-Bonsai-2-27B-PTQ1_0.gguf";
  url = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/839bd57023c1558945afea70a74fa83c054f35f9/Ternary-Bonsai-2-27B-PTQ1_0.gguf";
  sha256 = "53107f530aa52eb00912263ab1ee29bd199261c87cd7b4ad4ca1318c1fe33ee3";
  passthru = {
    repository = "prism-ml/Ternary-Bonsai-2-27B-gguf";
    revision = "839bd57023c1558945afea70a74fa83c054f35f9";
    size = 5946648928;
    quantization = "PTQ1_0";
    # Needs pkgs.fmf.llama-cpp-prism. Not loadable by stock llama.cpp. Weights are in a Hadamard-rotated
    # basis; the runtime must apply the matching activation transform (the file declares it as metadata).
    runtime = "prism";
  };
  meta = {
    description = "Ternary Bonsai 2 27B PTQ1_0 GGUF (dense trits, 1.75 bpw; PrismML fork only: stock llama.cpp rejects the type)";
    homepage = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
