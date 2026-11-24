{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Inkling-2-Mini-UD-Q3_K_XL.gguf";
  url = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/8078d149286eec7193795413b9e0643da6d11fa1/Inkling-2-Mini-UD-Q3_K_XL.gguf";
  sha256 = "e2d03e8c92ac21cff0e3309b95f40dfd27d1825184f0d2bc09db249797273639";
  passthru = {
    repository = "unsloth/Inkling-2-Mini-GGUF";
    revision = "8078d149286eec7193795413b9e0643da6d11fa1";
    size = 13631779296;
    quantization = "UD-Q3_K_XL";
    # Not in the llama.cpp catalog: with the desktop on the same card it does not fit fully on the GPU, and
    # partial CPU placement of the looped layers corrupts output (ggml-org/llama.cpp#32710). Kept so it can
    # be selected on a card with the room.
    runtime = "mainline";
  };
  meta = {
    description = "Inkling 2 Mini UD-Q3_K_XL GGUF (Unsloth, mainline llama.cpp layout; 13.63 GB, does not fit a 16 GB card shared with a desktop)";
    homepage = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
