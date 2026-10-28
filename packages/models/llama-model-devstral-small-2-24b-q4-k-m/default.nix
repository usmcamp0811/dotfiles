{pkgs, lib, ...}:
pkgs.fetchurl {
  name = "Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf";
  url = "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/resolve/6e458b8add42681bfd023de5eab93637694aaf82/Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf";
  sha256 = "d14ba9edee1bb4c4996a726deb81e49ae81800a3216f0774634238c380aee496";
  passthru = {
    repository = "unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF";
    revision = "6e458b8add42681bfd023de5eab93637694aaf82";
    size = 14334446752;
    quantization = "Q4_K_M";
    # Base model card says Apache-2.0; the quant repository's metadata says
    # "other". Preserve that distinction rather than inventing a license.
    baseModelLicense = "Apache-2.0";
  };
  meta = {
    description = "Devstral Small 2 24B Instruct Q4_K_M GGUF (text-only without projector)";
    homepage = "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
