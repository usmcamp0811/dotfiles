{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Qwen3.5-9B-UD-Q4_K_XL.gguf";
  url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/3885219b6810b007914f3a7950a8d1b469d598a5/Qwen3.5-9B-UD-Q4_K_XL.gguf";
  hash = "sha256-b10wZmwtiuFqMG5hbZU0Hc88xGgQ34TX5vWn0eTBspM=";
  passthru = {
    repository = "unsloth/Qwen3.5-9B-GGUF";
    revision = "3885219b6810b007914f3a7950a8d1b469d598a5";
    size = 5966095584;
    quantization = "UD-Q4_K_XL";
  };
  meta = {
    description = "Qwen3.5 9B UD-Q4_K_XL GGUF (text-only; vision projector not included)";
    homepage = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
