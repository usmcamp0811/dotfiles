{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Ternary-Bonsai-2-27B-Q2_0.gguf";
  url = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/839bd57023c1558945afea70a74fa83c054f35f9/Ternary-Bonsai-2-27B-Q2_0.gguf";
  sha256 = "4f99aed01b8a877e153f9aa6569a4440fe17c59701cc0953e36d7f460549e70e";
  passthru = {
    repository = "prism-ml/Ternary-Bonsai-2-27B-gguf";
    revision = "839bd57023c1558945afea70a74fa83c054f35f9";
    size = 7626008928;
    quantization = "Q2_0";
    # Stock llama.cpp older than b11556 loads this WITHOUT any warning and produces garbage.
    runtime = "mainline";
  };
  meta = {
    description = "Ternary Bonsai 2 27B Q2_0 GGUF (2.25 bpw; stock llama.cpp b11556 or newer, the PrismML fork also runs it)";
    homepage = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
