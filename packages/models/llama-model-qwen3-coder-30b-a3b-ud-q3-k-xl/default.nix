{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf";
  url = "https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/b17cb02dd882d5b6ab62fc777ad2995f19668350/Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf";
  hash = "sha256-ac11eNd9/8CxfjS62e+ZjQiuDiDMzu8hutTn6z2MVTs=";
  passthru = {
    repository = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
    revision = "b17cb02dd882d5b6ab62fc777ad2995f19668350";
    size = 13806312608;
    quantization = "UD-Q3_K_XL";
  };
  meta = {
    description = "Qwen3 Coder 30B A3B Instruct Unsloth Dynamic Q3_K_XL GGUF";
    homepage = "https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
