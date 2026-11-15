{pkgs, lib, inputs, ...}: let
  # A stand-in for pkgs.fmf.strata that only has the attributes the module reads, so this evaluation does not
  # pull in the CUDA toolchain, the engine build or any model weights.
  fakePack = pkgs.writeTextDir "tokenizer/vocab.json" "{}";
  fakeStrata =
    (pkgs.writeShellScriptBin "strata-server" "exit 0")
    // {
      enginePath = "/fake/libexec/strata/strata";
      enginePathDsv41 = "/fake/libexec/strata/strata-dsv41";
      tokenizerFor = _: pkgs.writeTextDir "tokenizer/vocab.json" "{}";
      # the sharded families: a farm, a pack and the draft layer's folder, as paths the module only interpolates
      farmFor = id: _: "/fake/farm/${id}";
      packFlashNext = _: _: fakePack;
      packDeepseek = _: _: fakePack;
      mtpRt = "/fake/mtp-rt";
      root = "/fake/root";
    };
  fakeModel = pkgs.writeText "fake-qwen36.gguf" "not-real-model-weights";
  catalog = (import ../../lib/strata-models {}).strataModels {inherit pkgs;};
  pt = p: p.passthru or p;
  testCatalog = lib.mapAttrs (_: m: m // {package = fakeModel;}) catalog;

  base = {
    system.stateVersion = "26.05";
    nixpkgs.config.allowUnfree = true;
    fmf.services.vault-agent = {
      enable = true;
      settings.vault = {
        address = "https://vault.example.invalid";
        role-id = "/synthetic/role-id";
        secret-id = "/synthetic/secret-id";
      };
    };
    fmf.services.strata = {
      enable = true;
      package = fakeStrata;
      models = testCatalog;
      host = "10.0.0.5";
      port = 18081;
      vramReserveMiB = 1536;
      poolWorkers = 12;
      lazyLoad = true;
      idleUnloadSeconds = 300;
      minFreeVramMiB = 4096;
      memoryMax = "64G";
      cpuAffinity = "0-7";
      vault = {
        enable = true;
        path = "secret/example/data/strata";
      };
    };
  };

  evalWith = extra:
    lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = {inherit lib inputs;};
      modules = [
        ../../modules/nixos/services/vault-agent
        ../../modules/nixos/services/strata
        base
        extra
      ];
    };

  evaluated = evalWith {};
  c = evaluated.config;
  unit = c.systemd.services.strata;
  # The module exposes what it generates as data, so nothing here builds or reads a derivation.
  runConfig = c.fmf.services.strata.generated.runConfigAttrs;
  launcherText = c.fmf.services.strata.generated.launcherText;
  runConfigText = builtins.toJSON runConfig;

  agent = c.detsys.vaultAgent.systemd.services.strata.agentConfig;
  method = builtins.head agent.auto_auth.method;
  template = c.fmf.services.vault-agent.services.strata.secrets.file.files.api-key.text;

  failing = cfgSystem: needle: lib.any (a: !a.assertion && lib.hasInfix needle a.message) cfgSystem.config.assertions;
  noAuth = evalWith {fmf.services.strata.vault.enable = lib.mkForce false;};
  bothAuth = evalWith {fmf.services.strata.apiKeyFile = "/run/keys/strata";};
  storeKey = evalWith {fmf.services.strata = {vault.enable = lib.mkForce false; apiKeyFile = "/nix/store/aaaa-key";};};
  badModel = evalWith {fmf.services.strata.model = "gpt-oss-20b";};

  # one evaluation per engine path; `base` sets vramReserveMiB 1536 and poolWorkers 12, which the paths pass differently
  withModel = id: extra: evalWith (lib.recursiveUpdate {fmf.services.strata.model = id;} extra);
  rcOf = sys: sys.config.fmf.services.strata.generated.runConfigAttrs;
  istaId = "qwen3.8-flash-next-iq3_s";
  flashIsta = rcOf (withModel istaId {});
  flashNoDraft = rcOf (withModel istaId {fmf.services.strata.mtp = 0;});
  flashCoder = rcOf (withModel "qwen3.8-flash-next-coder-iq1_m" {});
  flashIq4xs = rcOf (withModel "qwen3.8-flash-next-unsloth-ud-iq4_xs" {});
  flashQ5 = rcOf (withModel "qwen3.8-flash-next-unsloth-ud-q5_k_xl" {});
  flashQ8Budget = rcOf (withModel "qwen3.8-flash-next-unsloth-q8_0" {fmf.services.strata.residentBudgetGiB = 104;});
  dsv200 = rcOf (withModel "deepseek-v4.1-flash-2.00bpw" {fmf.services.strata.poolWorkers = lib.mkForce null;});
  dsv200Unit = (withModel "deepseek-v4.1-flash-2.00bpw" {fmf.services.strata.poolWorkers = lib.mkForce null;}).config.systemd.services.strata;
  expertVramOnFlash = withModel istaId {fmf.services.strata.expertVramGiB = 10;};
  budgetOnIsta = withModel istaId {fmf.services.strata.residentBudgetGiB = 100;};
  poolOnDeepseek = withModel "deepseek-v4.1-flash-2.00bpw" {};
  # sizes in tenths of a GB, rounded: the figure upstream's setup.py (MODELS, "download_gb") gives for the same files
  gb10 = n: builtins.floor (n / 1.0e8 + 0.5);
  size = id: catalog.${id}.fileBytes;
  shardPath = id: i: (builtins.elemAt catalog.${id}.files i).path.outPath;
  oldDriver = evalWith {hardware.nvidia.package = lib.mkForce ((pkgs.runCommand "old-nvidia" {} "touch $out") // {version = "570.0";});};
  fileKey = evalWith {fmf.services.strata = {vault.enable = lib.mkForce false; apiKeyFile = "/run/keys/strata";};};
  disabled = evalWith {fmf.services.strata.enable = lib.mkForce false;};
in
  # --- catalog: only Strata-supported models, one served id, accurate limits ---
  assert builtins.attrNames catalog == [
    "deepseek-v4.1-flash-1.75bpw"
    "deepseek-v4.1-flash-2.00bpw"
    "deepseek-v4.1-flash-2.25bpw"
    "qwen3.6-35b-a3b-q8_0"
    "qwen3.6-35b-a3b-ud-q4_k_xl"
    "qwen3.6-35b-a3b-ud-q6_k_xl"
    "qwen3.8-flash-next-coder-iq1_m"
    "qwen3.8-flash-next-iq2_xs"
    "qwen3.8-flash-next-iq3_s"
    "qwen3.8-flash-next-iq3_xxs"
    "qwen3.8-flash-next-q2_0"
    "qwen3.8-flash-next-unsloth-q8_0"
    "qwen3.8-flash-next-unsloth-ud-iq4_xs"
    "qwen3.8-flash-next-unsloth-ud-q4_k_xl"
    "qwen3.8-flash-next-unsloth-ud-q5_k_xl"
    "qwen3.8-flash-next-unsloth-ud-q6_k_xl"
  ];
  assert lib.all (m: m.maxOutputTokens == 2048 && m.contextSize > 8192 && m.name != "") (builtins.attrValues catalog);
  # three engine paths, by family; only qwen36 and DeepSeek write a GGUF architecture
  assert lib.mapAttrs (_: m: m.family) (lib.filterAttrs (n: _: lib.hasPrefix "qwen3.8" n) catalog) == lib.genAttrs (builtins.filter (lib.hasPrefix "qwen3.8") (builtins.attrNames catalog)) (_: "flashnext");
  assert lib.all (m: m.family == "deepseek41" && m.arch == "deepseek41") (builtins.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "deepseek" n) catalog));
  assert lib.all (m: !(m ? arch)) (builtins.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "qwen3.8" n) catalog));
  # the sizes are the sums of the pinned shards and equal the download figures in upstream's setup.py MODELS
  assert gb10 (size "qwen3.8-flash-next-q2_0") == 664 && gb10 (size "qwen3.8-flash-next-iq2_xs") == 680;
  assert gb10 (size "qwen3.8-flash-next-iq3_xxs") == 758 && gb10 (size "qwen3.8-flash-next-iq3_s") == 836;
  assert gb10 (size "qwen3.8-flash-next-coder-iq1_m") == 584;
  assert gb10 (size "qwen3.8-flash-next-unsloth-ud-iq4_xs") == 937 && gb10 (size "qwen3.8-flash-next-unsloth-ud-q4_k_xl") == 1113;
  assert gb10 (size "qwen3.8-flash-next-unsloth-ud-q5_k_xl") == 1583 && gb10 (size "qwen3.8-flash-next-unsloth-ud-q6_k_xl") == 1692;
  assert gb10 (size "qwen3.8-flash-next-unsloth-q8_0") == 1882;
  # a file several sets share is one store path: the n-gram table (shard 2) of every ISTA size and the Coder, and
  # Unsloth's shards 2 and 3 in Q5, Q6 and Q8_0; a file that differs is not
  assert shardPath "qwen3.8-flash-next-q2_0" 1 == shardPath "qwen3.8-flash-next-iq3_s" 1;
  assert shardPath "qwen3.8-flash-next-q2_0" 1 == shardPath "qwen3.8-flash-next-coder-iq1_m" 1;
  assert shardPath "qwen3.8-flash-next-q2_0" 0 != shardPath "qwen3.8-flash-next-iq3_s" 0;
  assert shardPath "qwen3.8-flash-next-unsloth-ud-q5_k_xl" 1 == shardPath "qwen3.8-flash-next-unsloth-q8_0" 1;
  assert shardPath "qwen3.8-flash-next-unsloth-ud-q5_k_xl" 2 == shardPath "qwen3.8-flash-next-unsloth-ud-q6_k_xl" 2;
  assert shardPath "qwen3.8-flash-next-unsloth-ud-q5_k_xl" 3 != shardPath "qwen3.8-flash-next-unsloth-ud-q6_k_xl" 3;
  # the sibling names the engine searches for (<name>-0000N-of-0000M.gguf) are kept, in order
  assert map (f: f.name) catalog."qwen3.8-flash-next-iq3_s".files == ["Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00001-of-00002.gguf" "Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00002-of-00002.gguf"];
  assert catalog."qwen3.8-flash-next-iq3_s".ple == "Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00002-of-00002.gguf";
  assert catalog."qwen3.8-flash-next-unsloth-ud-q4_k_xl".ple == null; # more than two shards: the engine finds the table
  assert builtins.length catalog."qwen3.8-flash-next-unsloth-q8_0".files == 6;
  assert builtins.length catalog."deepseek-v4.1-flash-2.25bpw".files == 4;
  # the draft layer and the Engram are shared, not per set
  assert catalog."deepseek-v4.1-flash-1.75bpw".engram.outPath == catalog."deepseek-v4.1-flash-2.25bpw".engram.outPath;
  assert (pt catalog."deepseek-v4.1-flash-2.00bpw".engram).size == 110595290816;
  # every set of the 2.00 bpw and 1.75 bpw kind uses upstream's profile-2.00.bin; 2.25 has its own
  assert catalog."deepseek-v4.1-flash-1.75bpw".profile == "profile-2.00.bin" && catalog."deepseek-v4.1-flash-2.25bpw".profile == "profile-2.25.bin";
  # Qwen3.6: every entry is on the qwen36 engine path, from the one pinned repository, with its own file size
  assert lib.all (m: m.arch == "qwen35moe" && m.contextSize == 65536) (builtins.attrValues (lib.filterAttrs (_: m: m.family == "qwen36") catalog));
  assert (pt catalog."qwen3.6-35b-a3b-ud-q6_k_xl".package).size == 32611711264;
  assert (pt catalog."qwen3.6-35b-a3b-ud-q6_k_xl".package).quantization == "UD-Q6_K_XL";
  assert (pt catalog."qwen3.6-35b-a3b-q8_0".package).size == 37801097504;
  assert (pt catalog."qwen3.6-35b-a3b-q8_0".package).quantization == "Q8_0";
  assert lib.all (m: (pt m.package).repository == "unsloth/Qwen3.6-35B-A3B-MTP-GGUF") (builtins.attrValues (lib.filterAttrs (_: m: m.family == "qwen36") catalog));
  assert catalog."qwen3.6-35b-a3b-ud-q4_k_xl".contextSize == 65536;
  assert catalog."qwen3.6-35b-a3b-ud-q4_k_xl".maxOutputTokens == 2048;
  assert catalog."qwen3.6-35b-a3b-ud-q4_k_xl".family == "qwen36";
  # none of the llama.cpp-only models is registered under Strata
  assert !(builtins.any (n: builtins.elem n ["gpt-oss-20b" "qwen3.5-9b" "qwen3-coder-30b-a3b" "devstral-small-2"]) (builtins.attrNames catalog));
  # the Strata model is a different artifact from the llama.cpp qwen3.6 file
  assert (pt catalog."qwen3.6-35b-a3b-ud-q4_k_xl".package).repository == "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
  assert (pt catalog."qwen3.6-35b-a3b-ud-q4_k_xl".package).quantization == "UD-Q4_K_XL";
  assert (pt catalog."qwen3.6-35b-a3b-ud-q4_k_xl".package).size == 22853663008;
  # --- disabled by default / when not enabled ---
  assert !(disabled.config.systemd.services ? strata);
  assert !(disabled.config.users.users ? strata);
  # --- unit ---
  assert unit.serviceConfig.User == "strata";
  assert unit.serviceConfig.Restart == "on-failure";
  assert unit.serviceConfig.MemoryMax == "64G";
  assert unit.serviceConfig.CPUAffinity == "0-7";
  assert unit.serviceConfig.LimitMEMLOCK == "infinity";
  assert unit.serviceConfig.NoNewPrivileges;
  assert !(unit.serviceConfig ? LoadCredential);
  assert builtins.elem "video" unit.serviceConfig.SupplementaryGroups;
  assert builtins.elem "render" unit.serviceConfig.SupplementaryGroups;
  assert unit.environment.HOME == "/var/lib/strata";
  # --- run config: engine args as upstream's setup.py writes them, plus the requested knobs ---
  assert runConfig.model_name == "qwen3.6-35b-a3b-ud-q4_k_xl";
  assert runConfig.arch == "qwen35moe";
  assert runConfig.port == 18081 && runConfig.host == "10.0.0.5";
  assert runConfig.exe == "/fake/libexec/strata/strata";
  assert lib.take 2 runConfig.args == ["--native" "${fakeModel}"];
  assert builtins.elem "--max-context" runConfig.args && builtins.elem "65536" runConfig.args;
  assert builtins.elem "--mtp" runConfig.args && builtins.elem "2" runConfig.args;
  assert builtins.elem "--vram-reserve-mib" runConfig.args && builtins.elem "1536" runConfig.args;
  assert builtins.elem "--pool-workers" runConfig.args && builtins.elem "12" runConfig.args;
  assert !(builtins.elem "--expert-vram" runConfig.args); # unset: the engine decides the placement
  assert !(builtins.elem "--vision" runConfig.args); # text only
  assert runConfig.lazy_load == true && runConfig.idle_unload_s == 300 && runConfig.min_free_vram_mib == 4096;
  assert !(runConfig ? api_key);
  assert !(lib.hasInfix "api_key" runConfigText);
  # the key reaches the server through the environment, never argv
  assert lib.hasInfix "export STRATA_API_KEY=" launcherText;
  assert !(lib.hasInfix "--api-key" launcherText);
  assert lib.hasInfix "--offline" launcherText;
  # --- Vault credential delivery ---
  assert agent.vault.address == "https://vault.example.invalid";
  assert builtins.length agent.auto_auth.method == 1;
  assert method.type == "approle";
  assert method.config.role_id_file_path == "/synthetic/role-id";
  assert method.config.remove_secret_id_file_after_reading == false;
  assert lib.hasInfix "secret/example/data/strata" template && lib.hasInfix ".Data.data" template;
  assert c.fmf.services.vault-agent.services.strata.secrets.file.files.api-key.permissions == "0400";
  assert c.fmf.services.vault-agent.services.strata.secrets.file.files.api-key.change-action == "restart";
  assert c.systemd.services.strata.unitConfig.JoinsNamespaceOf == "detsys-vaultAgent-strata.service";
  # runtime key file variant uses a systemd credential, not a store path
  assert fileKey.config.systemd.services.strata.serviceConfig.LoadCredential == ["api-key:/run/keys/strata"];
  # --- refusals: an unauthenticated or misconfigured instance must not evaluate cleanly ---
  assert failing noAuth "always requires an API key";
  assert failing bothAuth "not both";
  assert failing storeKey "outside /nix/store";
  assert failing badModel "is not in the Strata catalog";
  # --- Qwen3.8 Flash Next (ISTA): the arguments setup_config.config_for writes, in its order, with no arch key ---
  assert flashIsta.args == [
    "--pack" "${fakePack}"
    "--native" "/fake/farm/${istaId}/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00001-of-00002.gguf"
    "--ple-gguf" "/fake/farm/${istaId}/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00002-of-00002.gguf"
    "--expert-profile" "/fake/root/data/expert-profile.bin"
    "--expert-cache" "auto" "--prefill" "auto" "--spec" "4"
    "--spec-min-p" "0.5" "--mtp" "/fake/mtp-rt"
    "--max-context" "32768" "--kv" "int8"
    "--vram-reserve-mib" "1536" "--pool-workers" "12"
  ];
  assert !(flashIsta ? arch) && !(flashIsta ? env) && !(flashIsta ? mtp);
  assert flashIsta.model_name == istaId && flashIsta.exe == "/fake/libexec/strata/strata" && flashIsta.tokenizer == "${fakePack}/tokenizer";
  # the draft layer off: `"mtp": false`, and --mtp and --spec-min-p go while --spec stays (draft_layer.py)
  assert flashNoDraft.mtp == false && !(builtins.elem "--mtp" flashNoDraft.args) && !(builtins.elem "--spec-min-p" flashNoDraft.args) && builtins.elem "--spec" flashNoDraft.args;
  # the Coder has its own profile
  assert builtins.elem "/fake/root/data/expert-profile-coder.bin" flashCoder.args;
  # Unsloth: three shards need no --ple-gguf; all-in-RAM writes STRATA_ROUTE_TAIL_SKIP=0; Q5 adds the K-quant kernels
  assert !(builtins.elem "--ple-gguf" flashIq4xs.args) && flashIq4xs.env == {STRATA_ROUTE_TAIL_SKIP = "0";};
  assert flashQ5.env == {STRATA_MMQ_KQ = "1"; STRATA_ROUTE_TAIL_SKIP = "0";};
  # a RAM budget replaces all-in-RAM: the flag is written and the env switch is not (Q8_0 has no K-quant kernels either)
  assert builtins.elem "--resident-budget-gib" flashQ8Budget.args && builtins.elem "104" flashQ8Budget.args && !(flashQ8Budget ? env);
  assert !(builtins.elem "--resident-budget-gib" flashQ5.args);
  # --- DeepSeek: its own engine, the pack and the context, never writing back to a pack in the store ---
  assert dsv200.args == [
    "--pack" "${fakePack}" "--max-context" "65536" "--eos" "1" "--vision" "off"
    "--dspark" "auto" "--dspark-conf" "0.65" "--profile-readonly" "--reserve-mib" "1536"
  ];
  assert dsv200.exe == "/fake/libexec/strata/strata-dsv41" && dsv200.arch == "deepseek41" && dsv200.engine_ready_s == 3600;
  assert dsv200.tokenizer == "${fakePack}/tokenizer" && !(dsv200 ? env) && !(dsv200 ? mtp);
  assert dsv200Unit.serviceConfig.User == "strata";
  # the Qwen3.6 engine's own run config is untouched by all of this
  assert !(runConfig ? engine_ready_s) && !(runConfig ? env) && !(runConfig ? mtp);
  # --- options that name a flag only one engine has are refused for the others ---
  assert failing expertVramOnFlash "expertVramGiB";
  assert failing budgetOnIsta "residentBudgetGiB";
  assert failing poolOnDeepseek "poolWorkers";
  assert failing oldDriver "needs NVIDIA driver 580";
  assert !(lib.any (a: !a.assertion && lib.hasInfix "trata" a.message) c.assertions);
  pkgs.runCommand "strata-config-regression" {} ''
    # Evaluation only: nothing runs and no model, engine or credential is read.
    touch "$out"
  ''
