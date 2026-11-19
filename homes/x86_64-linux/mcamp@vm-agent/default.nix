{lib, ...}:
with lib;
with lib.fmf; {
  # The agent's shell: the same headless profile as the other machines (zsh, neovim, yazi,
  # git, direnv, ...) plus opencode, minus everything that holds credentials or phones out.
  fmf = {
    user = {
      enable = true;
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
    };

    archetypes.headless = enabled;

    # Part of the headless profile but wrong for a sandbox:
    services.syncthing.enable = mkForce false; # would sync the workspace to other devices
    services.openssh.enable = mkForce false; # ssh client config forwards your agent to every host
    cli.k9s.enable = mkForce false;

    tools.agentic-ai = {
      enable = true;
      enableDistill = true;

      # llama.cpp on sledge (the provider and its Vault-rendered key come from
      # fmf.services.llama-cpp-client in systems/x86_64-linux/vm-agent). No Anthropic OAuth: its tokens
      # would be stored in this VM.
      opencodeModel = "llama-cpp/qwen3-coder-30b-a3b";
      enableOpencodeAnthropicAuthPlugin = true;

      remoteSkills = [
        "@anthropics/skills/frontend-design"
        "@fellipeutaka/leon/playwright"
      ];
    };
  };

  home.stateVersion = "26.05";
}
