# Router security hardening module
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.router.security;
  routerCfg = config.campground.router;
in {
  options.campground.router.security = {
    enable = mkEnableOption "Router security hardening" // {default = routerCfg.enable;};

    enableSSH = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SSH server (LAN only)";
    };

    sshPort = mkOption {
      type = types.int;
      default = 22;
      description = "SSH port";
    };

    enableWebUI = mkOption {
      type = types.bool;
      default = false;
      description = "Enable web UI for management (future implementation)";
    };

    allowedServices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          port = mkOption {
            type = types.int;
            description = "Port number";
          };
          protocol = mkOption {
            type = types.enum ["tcp" "udp"];
            description = "Protocol";
          };
          interface = mkOption {
            type = types.str;
            default = "br-lan";
            description = "Interface to allow service on";
          };
        };
      });
      default = [];
      description = "Additional services to allow";
    };

    fail2ban = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable fail2ban for SSH protection";
      };

      maxRetry = mkOption {
        type = types.int;
        default = 3;
        description = "Maximum retry attempts before ban";
      };

      banTime = mkOption {
        type = types.int;
        default = 3600;
        description = "Ban time in seconds";
      };
    };
  };

  config = mkIf (routerCfg.enable && cfg.enable) {
    # Disable unnecessary services
    services.avahi.enable = mkForce false;
    services.printing.enable = mkForce false;
    sound.enable = mkForce false;
    # hardware.pulseaudio.enable = mkForce false;

    # SSH configuration - LAN only
    services.openssh = mkIf cfg.enableSSH {
      enable = true;
      ports = [cfg.sshPort];

      settings = {
        # Security settings
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;

        # Performance
        UseDNS = false;

        # Only allow from LAN
        ListenAddress = routerCfg.lan.gateway;
      };

      # Modern key exchange algorithms
      extraConfig = ''
        # Only allow modern ciphers
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
        KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
      '';
    };

    # Firewall for SSH (LAN only)
    # merged networking.firewall.interfaces
    networking.firewall.interfaces =
      {
        # SSH rule for br-lan
        "br-lan" = mkIf cfg.enableSSH {
          allowedTCPPorts = [cfg.sshPort];
        };
      }
      # merge in dynamically generated allowedServices rules
      // (listToAttrs (
        map (
          service:
            nameValuePair service.interface {
              allowedTCPPorts = mkIf (service.protocol == "tcp") [service.port];
              allowedUDPPorts = mkIf (service.protocol == "udp") [service.port];
            }
        )
        cfg.allowedServices
      ));

    # fail2ban for SSH protection
    services.fail2ban = mkIf (cfg.enableSSH && cfg.fail2ban.enable) {
      enable = true;
      maxretry = cfg.fail2ban.maxRetry;
      bantime = "${toString cfg.fail2ban.banTime}";

      jails = {
        sshd = {
          enabled = true;
          filter = "sshd";
          action = "nftables-allports";
        };
      };
    };

    # System security hardening
    security = {
      # Protect kernel modules
      protectKernelImage = true;

      # Restrict ptrace
      allowUserNamespaces = true;
      unprivilegedUsernsClone = false;
    };

    # Additional kernel hardening
    boot.kernel.sysctl = {
      # Disable IPv6 if not enabled
      "net.ipv6.conf.all.disable_ipv6" = mkIf (!routerCfg.enableIPv6) 1;
      "net.ipv6.conf.default.disable_ipv6" = mkIf (!routerCfg.enableIPv6) 1;

      # Additional security
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.printk" = "3 3 3 3";
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;

      # Protect against SYN flood
      "net.ipv4.tcp_max_syn_backlog" = 2048;
      "net.ipv4.tcp_synack_retries" = 2;
      "net.ipv4.tcp_syn_retries" = 5;

      # Protect against time-wait assassination
      "net.ipv4.tcp_rfc1337" = 1;

      # Log martian packets
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
    };

    # Enable audit
    security.audit.enable = true;
    security.auditd.enable = true;

    # Clean temporary files
    boot.tmp.cleanOnBoot = true;

    # Disable coredumps
    systemd.coredump.enable = false;

    # Logging configuration for routers
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=7day
    '';

    # NTP for accurate time sync (important for security logging)
    services.timesyncd.enable = true;

    # Create security monitoring script
    environment.systemPackages =
      [
        (pkgs.writeScriptBin "router-security-check" ''
          #!${pkgs.bash}/bin/bash
          echo "=== Router Security Status ==="
          echo ""
          echo "Firewall Status:"
          ${pkgs.systemd}/bin/systemctl status nftables.service | ${pkgs.gnugrep}/bin/grep -E "(Active|Loaded)"
          echo ""
          echo "SSH Status:"
          ${pkgs.systemd}/bin/systemctl status sshd.service | ${pkgs.gnugrep}/bin/grep -E "(Active|Loaded)"
          echo ""
          echo "Active Connections:"
          ${pkgs.nettools}/bin/netstat -tn | ${pkgs.gnugrep}/bin/grep ESTABLISHED | wc -l
          echo ""
          echo "Recent SSH Attempts:"
          ${pkgs.systemd}/bin/journalctl -u sshd.service --since "1 hour ago" | ${pkgs.gnugrep}/bin/grep -i "failed\|accepted" | tail -10
          echo ""
          ${optionalString cfg.fail2ban.enable ''
            echo "fail2ban Status:"
            ${pkgs.fail2ban}/bin/fail2ban-client status sshd 2>/dev/null || echo "No bans"
            echo ""
          ''}
        '')
      ]
      ++ (with pkgs; [
        # Essential tools
        vim
        htop
        tcpdump
        ethtool
        conntrack-tools

        # Network diagnostics
        inetutils
        dnsutils
        nmap

        # Security tools
        iptables
        nftables
      ]);
  };
}
