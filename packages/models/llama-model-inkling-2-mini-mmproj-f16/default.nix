{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "mmproj-F16.gguf";
  url = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/8078d149286eec7193795413b9e0643da6d11fa1/mmproj-F16.gguf";
  sha256 = "3bff75ffeb2d6e0371ba7bd42e30d26a7d98aea681fa44b03b5a20891cfa2c5f";
  passthru = {
    repository = "unsloth/Inkling-2-Mini-GGUF";
    revision = "8078d149286eec7193795413b9e0643da6d11fa1";
    size = 639348160;
    quantization = "F16";
    # Same file as Old_Support/mmproj-F16.gguf; Unsloth's mainline instructions use it unchanged.
    runtime = "mainline";
  };
  meta = {
    description = "Inkling 2 Mini vision projector (F16, 639 MB)";
    homepage = "https://huggingface.co/unsloth/Inkling-2-Mini-GGUF";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
