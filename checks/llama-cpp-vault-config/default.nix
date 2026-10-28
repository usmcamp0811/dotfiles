{pkgs, lib, inputs, ...}: let
  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {inherit lib inputs;};
    modules = [
      ../../modules/nixos/services/vault-agent
      ../../modules/nixos/services/llama-cpp
      {
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
        fmf.services.llama-cpp = {
          enable = true;
          package = pkgs.writeShellScriptBin "llama-server" "exit 0";
          model = null;
          vault = {enable = true; path = "secret/example/data/llama-cpp";};
        };
      }
    ];
  };
  c = evaluated.config;
  agent = c.detsys.vaultAgent.systemd.services.llama-cpp.agentConfig;
  method = builtins.head agent.auto_auth.method;
  template = c.fmf.services.vault-agent.services.llama-cpp.secrets.file.files.api-key.text;
  missingAuth = (evaluated.extendModules {modules = [{
    fmf.services.vault-agent.settings.vault = lib.mkForce {};
  }];}).config;
  wrongPath = (evaluated.extendModules {modules = [{
    fmf.services.llama-cpp.vault.path = lib.mkForce "secret/example/llama-cpp";
  }];}).config;
in
assert agent.vault.address == "https://vault.example.invalid";
assert builtins.length agent.auto_auth.method == 1;
assert method.type == "approle";
assert method.config.role_id_file_path == "/synthetic/role-id";
assert method.config.secret_id_file_path == "/synthetic/secret-id";
assert method.config.remove_secret_id_file_after_reading == false;
assert lib.hasInfix "secret/example/data/llama-cpp" template;
assert lib.hasInfix ".Data.data" template;
assert c.systemd.services.llama-cpp.unitConfig.JoinsNamespaceOf == "detsys-vaultAgent-llama-cpp.service";
assert lib.any (a: !a.assertion && lib.hasInfix "requires a Vault address" a.message) missingAuth.assertions;
assert lib.any (a: !a.assertion && lib.hasInfix "KV v2 API path" a.message) wrongPath.assertions;
pkgs.runCommand "llama-cpp-vault-config-regression" {} ''
  # Evaluation only: no Vault executable runs, and synthetic paths are not read.
  touch "$out"
''
