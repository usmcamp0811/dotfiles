{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Inkling-2-Mini-UD-IQ3_XXS.gguf";
  url = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/8078d149286eec7193795413b9e0643da6d11fa1/Inkling-2-Mini-UD-IQ3_XXS.gguf";
  sha256 = "fd9ccedae17c1bb89744612fbb46730b5275f2a342133d0419776bd1ae311657";
  passthru = {
    repository = "unsloth/Inkling-2-Mini-GGUF";
    revision = "8078d149286eec7193795413b9e0643da6d11fa1";
    size = 11663310784;
    quantization = "UD-IQ3_XXS";
    # Repository root = the mainline-compatible layout (identical to its Mainline_Support/ copy). Old_Support/
    # is the layout for Unsloth's own llama.cpp fork and is NOT what this is.
    runtime = "mainline";
  };
  meta = {
    description = "Inkling 2 Mini UD-IQ3_XXS GGUF (Unsloth, mainline llama.cpp layout; sparse MoE, looped transformer)";
    homepage = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
