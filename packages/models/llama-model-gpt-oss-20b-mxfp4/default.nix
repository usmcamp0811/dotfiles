{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "gpt-oss-20b-MXFP4.gguf";
  url = "https://huggingface.co/ggml-org/gpt-oss-20b-GGUF/resolve/15dcfc7e7c608c6161507211ed43c5b590801b4b/gpt-oss-20b-MXFP4.gguf";
  hash = "sha256-J81sQyx2csuBKpL2Ec87p7vDWSgmK7HhJT/07mrjWQE=";
  passthru = {
    repository = "ggml-org/gpt-oss-20b-GGUF";
    revision = "15dcfc7e7c608c6161507211ed43c5b590801b4b";
    size = 12109566624;
    quantization = "MXFP4";
  };
  meta = {
    description = "GPT-OSS 20B MXFP4 GGUF";
    homepage = "https://huggingface.co/ggml-org/gpt-oss-20b-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
