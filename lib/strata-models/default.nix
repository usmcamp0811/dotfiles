{...}: {
  # Models the Strata engine can serve, with the numbers OpenCode needs. Like llamaCppModels this stays lazy:
  # Home Manager reads only names and token limits, never `package`, so remote clients do not acquire weights.
  #
  # ONE Strata instance serves ONE model and answers every request with it whatever the request's "model" says
  # (serve/server.py model_for: "Other names are still served"). So an instance advertises exactly one model, the
  # one `fmf.services.strata.model` selects. The attribute name below is the id Strata itself reports in /v1/models
  # (the run config's model_name; upstream's convention is "<family name>-<size lowercased>").
  #
  # Only families Strata documents are listed: DeepSeek V4.1-Flash, Qwen3.8-Flash-Next and Qwen3.6-35B-A3B. The
  # llama.cpp catalog's other models (gpt-oss-20b, qwen3.5-9b, qwen3-coder-30b-a3b, devstral-small-2) are not in any
  # of those families and stay on llama.cpp. The llama.cpp qwen3.6 file (UD-IQ3_S, plain GGUF repo) is not a Strata
  # artifact either: see packages/models/strata-model-qwen36-35b-a3b-ud-q4-k-xl.
  strataModels = {pkgs}: let
    inherit (pkgs) lib;
    pins = import ./pins.nix;

    # One fetch per file at the revision upstream pins (pins.nix, generated from setup.py and checked against the Hub).
    # The store name comes from the content hash, not from the file name: a file that several sets share (ISTA's 28.8 GB
    # n-gram table is the same file in every size and in the Coder; Unsloth's shards 2 and 3 are the same in UD-Q5_K_XL,
    # UD-Q6_K_XL and Q8_0) is then one store path, however many sets name it. Nothing reads the store name: the farm
    # (packages/applications/strata `farmFor`) gives each model its own file names back.
    # LICENSE: the Qwen3.8 repositories disagree (the base model's card says qwen-community-1.0, ISTA's GGUF cards say
    # apache-2.0), so those files are marked unfree rather than claiming redistribution rights, as the Devstral package
    # is. Both DeepSeek repositories say MIT.
    fetch = repo: sub: file: let
      pin = pins.files.${file};
      rev = pins.revisions.${repo};
    in
      pkgs.fetchurl {
        name = "strata-gguf-${builtins.substring 0 16 pin.sha256}.gguf";
        url = "https://huggingface.co/${repo}/resolve/${rev}/${lib.optionalString (sub != "") "${sub}/"}${file}";
        inherit (pin) sha256;
        passthru = {
          repository = repo;
          revision = rev;
          inherit (pin) size;
          inherit file;
        };
        meta = {
          description = "${file} from ${repo}, for Strata";
          homepage = "https://huggingface.co/${repo}";
          license =
            if lib.hasPrefix "ISTA-DASLab/DeepSeek" repo || lib.hasPrefix "unsloth/DeepSeek" repo
            then lib.licenses.mit
            else lib.licenses.unfree;
          platforms = lib.platforms.all;
        };
      };

    sizeOf = names: lib.foldl' (acc: n: acc + pins.files.${n}.size) 0 names;
    numbered = n: lib.range 1 n;
    shard = i: toString i;

    # Qwen3.8-Flash-Next. These files are not read as one GGUF: setup.py packs shard 1 with tools/iq_pack.py (the
    # pack holds the index, dense weights and tokenizer; the experts stay in the shards), fetches the MTP draft layer
    # and starts the engine with `--pack --native <shard 1> --mtp <folder>`. Unlike qwen36 there is no "arch" key in
    # the run config (the server defaults to qwen4exp) and `--mtp` names a folder, not a count.
    # contextSize 32768 is what setup.py writes for a 32K context (`--kv int8`, no KV streaming, which starts at 64K).
    # ramGB and arenaGB are upstream's figures (setup.py MODELS): arenaGB is the routed experts, which an ISTA file
    # keeps whole in a pinned RAM arena; ramGB is its planning figure (for an Unsloth file the RAM-budget floor, or
    # the all-in-RAM need for UD-Q5_K_XL and above).
    mkFlash = {
      title,
      recipe,
      repo,
      sub,
      shardNames,
      ramGB,
      arenaGB,
      packArgs ? [],
      profile ? "expert-profile.bin",
      mmqKq ? false,
    }: let
      drvs = map (n: fetch repo sub n) shardNames;
    in {
      package = builtins.head drvs;
      family = "flashnext";
      inherit recipe packArgs profile mmqKq ramGB arenaGB;
      name = title;
      files = lib.zipListsWith (name: path: {inherit name path;}) shardNames drvs;
      native = builtins.head shardNames;
      # setup.py passes --ple-gguf for a model of at most two shards (the n-gram table is shard 2); with more shards the
      # engine finds the shard that holds per_layer_token_embd.weight by itself.
      ple =
        if builtins.length shardNames <= 2
        then lib.last shardNames
        else null;
      contextSize = 32768;
      maxOutputTokens = 2048;
      fileBytes = sizeOf shardNames;
    };

    istaRepo = "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF";
    istaSizes = {
      Q2_0 = {ramGB = 48; arenaGB = 34.0;};
      IQ2_XS = {ramGB = 48; arenaGB = 35.5;};
      IQ3_XXS = {ramGB = 60; arenaGB = 42.9;};
      IQ3_S = {ramGB = 62; arenaGB = 50.3;};
    };
    ista = lib.mapAttrs' (q: s:
      lib.nameValuePair "qwen3.8-flash-next-${lib.toLower q}" (mkFlash {
        title = "Qwen3.8 Flash Next (${q}, Strata)";
        recipe = "ista";
        repo = istaRepo;
        sub = q;
        shardNames = map (i: "Qwen3.8-Flash-Next-GSQ-RCO-${q}-0000${shard i}-of-00002.gguf") (numbered 2);
        inherit (s) ramGB arenaGB;
      }))
    istaSizes;

    # ISTA-DASLab's expert-pruned release (half the experts, kept for code, tools and images): one size, the
    # original's n-gram table as shard 2, and its own hot-expert profile.
    coder = {
      "qwen3.8-flash-next-coder-iq1_m" = mkFlash {
        title = "Qwen3.8 Flash Next Coder (IQ1_M, Strata)";
        recipe = "coder";
        repo = "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF";
        sub = "IQ1_M";
        shardNames = map (i: "Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-0000${shard i}-of-00002.gguf") (numbered 2);
        profile = "expert-profile-coder.bin";
        ramGB = 32;
        arenaGB = 23.4;
      };
    };

    # Unsloth's 4 to 8 bit files: packed with --compat-bf16. The K-quant MMQ prompt kernels (STRATA_MMQ_KQ) are
    # upstream's default for UD-Q5_K_XL and UD-Q6_K_XL only.
    unslothSizes = {
      "UD-IQ4_XS" = {n = 3; ramGB = 48; arenaGB = 59.5;};
      "UD-Q4_K_XL" = {n = 4; ramGB = 48; arenaGB = 77.0;};
      "UD-Q5_K_XL" = {n = 6; ramGB = 108; arenaGB = 98.4; mmqKq = true;};
      "UD-Q6_K_XL" = {n = 6; ramGB = 118; arenaGB = 109.2; mmqKq = true;};
      "Q8_0" = {n = 6; ramGB = 136; arenaGB = 128.3;};
    };
    unsloth = lib.mapAttrs' (q: s:
      lib.nameValuePair "qwen3.8-flash-next-unsloth-${lib.toLower q}" (mkFlash {
        title = "Qwen3.8 Flash Next (Unsloth ${q}, Strata)";
        recipe = "unsloth";
        repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
        sub = q;
        shardNames = map (i: "Qwen3.8-Flash-Next-${q}-0000${shard i}-of-0000${toString s.n}.gguf") (numbered s.n);
        packArgs = ["--compat-bf16"];
        mmqKq = s.mmqKq or false;
        inherit (s) ramGB arenaGB;
      }))
    unslothSizes;

    # DeepSeek V4.1-Flash-1017, ISTA-DAS's official 2-bit sets (the four-shard layout upstream pins). It has its own
    # engine binary and pack recipe (setup.py install_dsv41, `dsv41_pack_cmd`): the pack is built from the four shards,
    # the shared Engram table (110.6 GB, the same file in every set), the DSpark drafter and the five-megabyte
    # metadata shard of Unsloth's UD-Q8_K_XL, which carries the Engram's hash parameters. The id is ours: upstream names
    # every set "deepseek-v4.1-flash". ramGB is upstream's planning figure; what does not fit in RAM and VRAM is read
    # from the SSD, so a 12 GB card with 46 to 64 GB of RAM ran these at about 5 to 11 tokens/s.
    # contextSize: upstream's default is 131072. 65536 is used here to match the other entries; the engine says what a
    # context needs before it allocates and refuses one that cannot fit.
    dsvRepo = "ISTA-DASLab/DeepSeek-V4.1-Flash-1017-GSQ-RCO-GGUF";
    dsvUnslothRepo = "unsloth/DeepSeek-V4.1-Flash-1017-GGUF";
    mkDeepseek = {
      bpw,
      quant,
      profile,
      ramGB,
    }: let
      shardNames = map (i: "DeepSeek-V4.1-Flash-1017-GSQ-RCO-${quant}-0000${shard i}-of-00004.gguf") (numbered 4);
      drvs = map (n: fetch dsvRepo "" n) shardNames;
      engramName = "DeepSeek-V4.1-Flash-Engram-IQ4_NL.gguf";
      dsparkName = "dspark-DeepSeek-V4.1-Flash-1017-Q8_0.gguf";
    in {
      package = builtins.head drvs;
      family = "deepseek41";
      recipe = "ista";
      arch = "deepseek41";
      name = "DeepSeek V4.1 Flash (ISTA-DAS ${bpw} bpw, Strata)";
      files = lib.zipListsWith (name: path: {inherit name path;}) shardNames drvs;
      engram = fetch dsvRepo "" engramName;
      dspark = fetch dsvUnslothRepo "" dsparkName;
      meta = fetch dsvUnslothRepo "UD-Q8_K_XL" "DeepSeek-V4.1-Flash-1017-UD-Q8_K_XL-00001-of-00009.gguf";
      inherit profile ramGB;
      contextSize = 65536;
      maxOutputTokens = 2048;
      fileBytes = sizeOf (shardNames ++ [engramName dsparkName]);
    };
    deepseek = {
      "deepseek-v4.1-flash-1.75bpw" = mkDeepseek {bpw = "1.75"; quant = "IQ1_M"; profile = "profile-2.00.bin"; ramGB = 34;};
      "deepseek-v4.1-flash-2.00bpw" = mkDeepseek {bpw = "2.00"; quant = "IQ2_XXS"; profile = "profile-2.00.bin"; ramGB = 40;};
      "deepseek-v4.1-flash-2.25bpw" = mkDeepseek {bpw = "2.25"; quant = "IQ2_XS"; profile = "profile-2.25.bin"; ramGB = 44;};
    };
  in
    ista
    // coder
    // unsloth
    // deepseek
    // {
    "qwen3.6-35b-a3b-ud-q4_k_xl" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-ud-q4-k-xl;
      name = "Qwen3.6 35B A3B (UD-Q4_K_XL, Strata)";
      family = "qwen36";
      # GGUF architecture; the run config's "arch".
      arch = "qwen35moe";
      # 64K matches the llama.cpp catalog so switching engines does not shrink a session. The engine keeps its KV
      # cache in VRAM at 11 * 2 * 256 * 2 * 4 = 45,056 bytes per token (setup.py kv_bytes_per_token): 2.75 GiB at 64K.
      # Strata's own default is 128K (5.5 GiB). The engine states what the sessions need before it allocates and
      # refuses a context that cannot fit, with the numbers.
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      # Draft tokens per step for greedy requests (setup.py "mtp": measured best on the maker's R9700).
      mtp = 2;
      # Upstream's planning figures: file 22.9 GB, "RAM setup plans for" 32 GB.
      fileBytes = 22853663008;
      ramGB = 32;
    };

    # The same repository, revision, engine path and limits at 6 and 8 bits (setup.py QWEN36_FILES, docs/MODELS.md).
    # Only the file and upstream's RAM planning figure differ; the KV cache per token does not depend on the quant.
    "qwen3.6-35b-a3b-ud-q6_k_xl" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-ud-q6-k-xl;
      name = "Qwen3.6 35B A3B (UD-Q6_K_XL, Strata)";
      family = "qwen36";
      arch = "qwen35moe";
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      mtp = 2;
      fileBytes = 32611711264;
      ramGB = 44;
    };
    "qwen3.6-35b-a3b-q8_0" = {
      package = pkgs.fmf.strata-model-qwen36-35b-a3b-q8-0;
      name = "Qwen3.6 35B A3B (Q8_0, Strata)";
      family = "qwen36";
      arch = "qwen35moe";
      contextSize = 65536;
      maxOutputTokens = 2048;
      kvBytesPerToken = 45056;
      mtp = 2;
      fileBytes = 37801097504;
      ramGB = 52;
    };
  };
}
