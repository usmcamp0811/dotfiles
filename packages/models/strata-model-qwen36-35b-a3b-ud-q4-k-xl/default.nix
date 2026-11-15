{pkgs, lib, ...}:
# The Qwen3.6-35B-A3B file Strata runs. NOT interchangeable with the llama.cpp catalog's
# llama-model-qwen36-35b-a3b-ud-iq3-s: Strata's qwen36 engine path reads Unsloth's *MTP* GGUFs (the file
# carries the MTP draft block it speculates with), from a different repository, and documents only
# UD-Q4_K_XL, UD-Q6_K_XL and Q8_0 for this family (docs/QWEN36.md, docs/MODELS.md). UD-IQ3_S is not among them.
# Revision, size and SHA-256 are the ones in Strata v0.2.13.1's setup.py (QWEN36_FILES); the revision is this
# repository's current commit and its LFS hash was checked equal to that pin.
pkgs.fetchurl {
  name = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
  url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/resolve/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
  hash = "sha256-VZg8WnWhq5aYJAd7O7PeQUboKpI0BytIrU6Pkq0/6fE=";
  passthru = {
    repository = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
    revision = "5bc3e238d916f48a861bac2f8a1990a0e9b7e98d";
    size = 22853663008;
    quantization = "UD-Q4_K_XL";
  };
  meta = {
    description = "Qwen3.6 35B A3B, Unsloth Dynamic Q4_K_XL GGUF with the MTP layer, for Strata";
    homepage = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
