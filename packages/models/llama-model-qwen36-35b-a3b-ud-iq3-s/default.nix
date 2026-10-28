{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Qwen3.6-35B-A3B-UD-IQ3_S.gguf";
  url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/a483e9e6cbd595906af30beda3187c2663a1118c/Qwen3.6-35B-A3B-UD-IQ3_S.gguf";
  hash = "sha256-ZqPKiIzhNIK0DDM9skMsDr3jp7E3VPwp8Mb16JcD7GY=";
  passthru = {
    repository = "unsloth/Qwen3.6-35B-A3B-GGUF";
    revision = "a483e9e6cbd595906af30beda3187c2663a1118c";
    size = 13676723168;
    quantization = "UD-IQ3_S";
  };
  meta = {
    description = "Qwen3.6 35B A3B, Unsloth Dynamic IQ3_S GGUF (text-only without projector)";
    homepage = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
