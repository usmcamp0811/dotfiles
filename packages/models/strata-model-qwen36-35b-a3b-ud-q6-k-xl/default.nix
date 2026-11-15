{pkgs, lib, ...}:
# Qwen3.6-35B-A3B UD-Q6_K_XL for Strata: the same repository, revision and engine path as the UD-Q4_K_XL package
# (strata-model-qwen36-35b-a3b-ud-q4-k-xl), at 6 bits. Size and SHA-256 are Strata v0.2.13.1's setup.py
# (QWEN36_FILES) and equal the LFS size and oid Hugging Face reports for this revision. Upstream plans 44 GB of RAM.
pkgs.fetchurl {
  name = "Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf";
  url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/resolve/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf";
  hash = "sha256-NfzplM02EEp9wb2KS98Td4FFZkwA/e9nc668kkblAZw=";
  passthru = {
    repository = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
    revision = "5bc3e238d916f48a861bac2f8a1990a0e9b7e98d";
    size = 32611711264;
    quantization = "UD-Q6_K_XL";
  };
  meta = {
    description = "Qwen3.6 35B A3B, Unsloth Dynamic Q6_K_XL GGUF with the MTP layer, for Strata";
    homepage = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
