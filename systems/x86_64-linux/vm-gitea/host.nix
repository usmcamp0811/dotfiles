# Host record for vm-gitea: what the fleet derives leases, DNS, port forwards and MicroVM hosting from.
# Spec: docs/HOST-MODEL.md. Edit it here; run `fleet` afterwards to regenerate network/generated/.
{...}: {
  fmf.host = {
    kind = "microvm";
    expose = [
      {
        description = "vm-Gitea Web UI";
        port = 3000;
        proto = "tcp";
      }
      {
        description = "vm-Gitea HTTPS (nginx proxy)";
        port = 8445;
        proto = "tcp";
      }
      {
        description = "vm-Gitea SSH";
        port = 22022;
        proto = "tcp";
      }
    ];
    network = {
      interfaces = {
        lan = {
          ip = "192.169.1.40";
          mac = "02:00:00:00:00:40";
          zone = "lan"; # static: the guest configures this address itself (see ./default.nix)
        };
      };
    };
    # Starts after the Vault VM: it reads its secrets through vault-agent.
    boot.after = ["vm-vault"];
    placement = {
      restartIfChanged = true;
      runsOn = "blue-ridge";
    };
  };
}
