{pkgs, lib, inputs, ...}: let
  # A stand-in for pkgs.fmf.strata that only has the attributes the module reads, so this evaluation does not
  # pull in the CUDA toolchain, the engine build or any model weights.
  fakeStrata =
    (pkgs.writeShellScriptBin "strata-server" "exit 0")
    // {
      enginePath = "/fake/libexec/strata/strata";
      tokenizerFor = _: pkgs.writeTextDir "tokenizer/vocab.json" "{}";
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
  oldDriver = evalWith {hardware.nvidia.package = lib.mkForce ((pkgs.runCommand "old-nvidia" {} "touch $out") // {version = "570.0";});};
  fileKey = evalWith {fmf.services.strata = {vault.enable = lib.mkForce false; apiKeyFile = "/run/keys/strata";};};
  disabled = evalWith {fmf.services.strata.enable = lib.mkForce false;};
in
  # --- catalog: only Strata-supported models, one served id, accurate limits ---
  assert builtins.attrNames catalog == ["qwen3.6-35b-a3b-q8_0" "qwen3.6-35b-a3b-ud-q4_k_xl" "qwen3.6-35b-a3b-ud-q6_k_xl"];
  # every entry is on the qwen36 engine path, from the one pinned repository, with its own file size
  assert lib.all (m: m.family == "qwen36" && m.arch == "qwen35moe" && m.contextSize == 65536) (builtins.attrValues catalog);
  assert (pt catalog."qwen3.6-35b-a3b-ud-q6_k_xl".package).size == 32611711264;
  assert (pt catalog."qwen3.6-35b-a3b-ud-q6_k_xl".package).quantization == "UD-Q6_K_XL";
  assert (pt catalog."qwen3.6-35b-a3b-q8_0".package).size == 37801097504;
  assert (pt catalog."qwen3.6-35b-a3b-q8_0".package).quantization == "Q8_0";
  assert lib.all (m: (pt m.package).repository == "unsloth/Qwen3.6-35B-A3B-MTP-GGUF") (builtins.attrValues catalog);
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
  assert failing oldDriver "needs NVIDIA driver 580";
  assert !(lib.any (a: !a.assertion && lib.hasInfix "trata" a.message) c.assertions);
  pkgs.runCommand "strata-config-regression" {} ''
    # Evaluation only: nothing runs and no model, engine or credential is read.
    touch "$out"
  ''
