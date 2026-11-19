{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  agentUser = "mcamp";

  # Public keys only. Set explicitly so fmf's common suite does not also authorize the
  # gitlab-runner key, which has no business inside the sandbox.
  authorizedKeys = [
    "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
  ];
in {
  # DEMO / REFERENCE: a sandboxed MicroVM for coding agents (opencode and friends), copied from the
  # downstream Campground flake to show how the agentic setup is put together. It is not placed on a
  # hypervisor here (see ./host.nix), so nothing in this flake runs it. See ./README.md.
  #
  # Trust model:
  #   * Network: a host-side bridge filter on the hypervisor lets this guest reach the internet plus
  #     DNS and the LAN reverse proxy, and nothing else on the LAN. Nothing in here can change that.
  #     (That filter lives in the downstream flake, on the hypervisor; it is not part of this file.)
  #   * Secrets: only what Vault's `vm-agent` AppRole grants: the model API keys, the opencode
  #     server password and a build-farm client certificate. No SSH keys, no user-secrets, no netrc.
  #     SSH agent forwarding into this VM is refused.
  #   * Nix: never builds locally. Substitutes from the LAN cache and cache.nixos.org, and sends
  #     every build to the farm. The agent user is not a trusted Nix user.
  #   * The agent user has no sudo.

  boot.loader.grub.enable = mkForce false;
  boot.loader.systemd-boot.enable = mkForce false;

  microvm = {
    hypervisor = "qemu";
    vcpu = 6;
    mem = 16192; # Nix evaluation and node tooling are hungry (avoid exactly 2048: QEMU bug)
    socket = "control.socket";

    # The store overlay and every share come from this VM's fmf.host record: see ./storage.nix.
    #   agent-home: shell history, opencode sessions, cloned repositories. Delete it to reset.
    #   mcamp-code: the hypervisor user's real ~/code, shared read-write at the same path, so edits
    #     in the sandbox and on the host are the same files. This is a deliberate exception to the
    #     trust model above: anything the agent does in here can read and write every repo there.
  };

  ############################################################
  # Network: address, gateway and DNS come from ./host.nix (fmf.host.network.derive)
  ############################################################
  networking.networkmanager.enable = mkForce false;
  networking.enableIPv6 = false;
  services.resolved.enable = true;

  time.timeZone = "America/Chicago";

  # Root fs is RAM; the persistent parts are the shares.
  fileSystems."/" = {
    device = "rootfs";
    fsType = "tmpfs";
    options = ["mode=755" "size=4G"];
  };

  ############################################################
  # Nix: substitute only, builds go to the farm
  ############################################################
  nix.optimise.automatic = mkForce false;
  nix.settings = {
    auto-optimise-store = mkForce false;

    # Never build in this VM: anything not substitutable is sent to the farm.
    max-jobs = 0;
    builders-use-substitutes = true;

    # fmf makes the primary user a trusted Nix user. Trusted users can override
    # substituters/builders/sandbox options, which would undo the two lines above.
    trusted-users = mkForce ["root"];
    allowed-users = mkForce ["root" agentUser];

    # LAN cache (read access needs no credentials) + upstream. No private caches, no netrc.
    substituters = mkForce [
      "https://niks3.lan.aicampground.com"
      "https://cache.nixos.org"
    ];
  };

  # Build-farm client: a Vault-issued certificate (CN ci-vm-agent), used only by the Nix daemon (root).
  fmf.services.nix-grpc-store.client.useFarm = true;

  # The netrc for private caches is not part of this VM's Vault scope.
  fmf.services.vault-agent.services.copyNETRC.enable = mkForce false;
  systemd.services.copyNETRC.enable = mkForce false;

  ############################################################
  # Model providers (self-hosted llama.cpp and Strata behind the LAN reverse proxy).
  # API keys are rendered by Vault into files only the agent user can read.
  ############################################################
  fmf.services.llama-cpp-client = {
    enable = true;
    baseURL = "https://llama.lan.aicampground.com/v1";
    vault.path = "secret/campground/data/llama-cpp";
  };
  fmf.services.strata-client = {
    enable = true;
    baseURL = "https://strata.lan.aicampground.com/v1";
    models = genAttrs ["qwen3.6-35b-a3b-ud-q4_k_xl"] (_: {});
    vault.path = "secret/campground/data/strata";
  };

  ############################################################
  # Shared opencode server: clients run `opencode attach` (fmf.apps.opencode-remote).
  # HTTP basic auth with a Vault-rendered password.
  ############################################################
  fmf.services.opencode-server = {
    enable = true;
    openFirewall = true;

    # The server talks to the model providers, so it needs both keys at start.
    environmentFiles = {
      LLAMA_CPP_API_KEY = config.fmf.services.llama-cpp-client.apiKeyFile;
      STRATA_API_KEY = config.fmf.services.strata-client.apiKeyFile;
    };

    # A busy VM must not look like a dead one: restart only after ~15 min of no answer.
    watchdog = {
      timeout = 60;
      failures = 10;
    };
  };

  # Compressed RAM swap: memory pressure becomes slowness before it becomes an OOM kill.
  zramSwap.enable = true;

  systemd.services.opencode-server = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      # Let only the OOM-killed process die, not every session in the unit.
      OOMPolicy = "continue";
      Restart = mkForce "always";
      TasksMax = "infinity";
      LimitNOFILE = 1048576;
      MemoryMax = "infinity";
      MemoryHigh = "infinity";
    };
  };

  ############################################################
  # Users and SSH
  ############################################################
  fmf = {
    suites.common = enabled;
    user = {
      name = agentUser;
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
      extraGroups = []; # not wheel, not docker
    };
    services = {
      crystal-forge.enable = mkForce false;
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/vm-agent/role-id";
          secret-id = "/var/lib/vault/vm-agent/secret-id";
        };
      };
      openssh = {
        enable = true;
        authorizedKeys = mkForce authorizedKeys;
      };
    };
  };

  services.openssh = {
    hostKeys = [
      {
        path = "/persist/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = mkForce false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = mkOverride 40 "prohibit-password";
      AllowUsers = [agentUser "root"];
      # fmf's ssh client config sets ForwardAgent yes for every host in this flake. Without
      # this, `ssh vm-agent` would hand your SSH agent (and every key behind it) to the sandbox.
      AllowAgentForwarding = mkForce false;
      AllowTcpForwarding = mkForce false;
      AllowStreamLocalForwarding = mkForce false;
      X11Forwarding = mkForce false;
      GatewayPorts = mkForce "no";
    };
  };

  # Key-only accounts; no password secret to provision.
  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = mkForce "!";
    openssh.authorizedKeys.keys = authorizedKeys;
  };
  # Snowfall Lib puts every user with a homes/<user>@<host> config into `wheel` by default.
  snowfallorg.users.${agentUser}.admin = false;
  users.users.${agentUser} = {
    hashedPasswordFile = mkForce null;
    extraGroups = mkForce ["users"];
  };

  # The home directory is a virtiofs share: it must be mounted before home-manager activates.
  systemd.services."home-manager-${agentUser}".unitConfig.RequiresMountsFor = ["/home/${agentUser}"];
  home-manager.users.${agentUser}.snowfallorg.user.name = agentUser;

  environment.systemPackages = with pkgs; [git curl jq ripgrep fd];

  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=100M
    MaxRetentionSec=1week
  '';

  system.stateVersion = "26.05";
}
