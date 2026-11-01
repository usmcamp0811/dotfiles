# Circuit Breaker agent (`cb-agent`): an outbound-only Go daemon that reports host
# telemetry and runs probes/discovery from the network segment it sits on.
#
# * Built from the pinned upstream source (packages/circuit-breaker-agent); the
#   upstream self-updater is disabled so the binary only ever changes via Nix.
# * Runs as an unprivileged system account, no capabilities, with AF_NETLINK
#   allowed (needed for the neighbour cache and interface listing; the unit that
#   upstream's installer writes omits it, which breaks discovery and probing).
# * Opens no listening socket and needs no inbound firewall rule.
# * Identity (device.key) lives in /var/lib/cb-agent and survives rebuilds. An
#   administrator still approves each new agent in the server UI (or you use a
#   short-lived enrollment token delivered as a protected credential).
# * The server's identity key and TLS pin are public but only known after the
#   server's first start, so they may be given inline or as runtime files.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.circuit-breaker;
  ag = cfg.agent;
  user = "cb-agent";
  runDir = "/run/cb-agent";

  # Runs as root before the agent: composes the (public) config the binary reads
  # from /etc/circuit-breaker/agent.toml, which is a symlink to this file.
  prepare = pkgs.writeShellScript "cb-agent-prepare" ''
    set -eu
    umask 022
    pk=${
      if ag.serverStaticPkFile != null
      then ''"$(${pkgs.coreutils}/bin/tr -d ' \r\n' < ${escapeShellArg ag.serverStaticPkFile})"''
      else escapeShellArg ag.serverStaticPk
    }
    pin=${
      if ag.tlsPinFile != null
      then ''"$(${pkgs.coreutils}/bin/tr -d ' \r\n' < ${escapeShellArg ag.tlsPinFile})"''
      else escapeShellArg ag.tlsPin
    }
    if ! printf '%s' "$pk" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9a-f]{64}$'; then
      echo "cb-agent: server_static_pk is not 64 hex characters" >&2
      exit 1
    fi
    if [ -n "$pin" ] && ! printf '%s' "$pin" | ${pkgs.gnugrep}/bin/grep -qE '^[A-Za-z0-9+/]{43}=$'; then
      echo "cb-agent: tls_pin is not a base64 SHA-256 digest" >&2
      exit 1
    fi
    tmp="$(${pkgs.coreutils}/bin/mktemp ${runDir}/.agent.toml.XXXXXX)"
    cat > "$tmp" <<EOF
    server_url = "${ag.serverUrl}"
    server_static_pk = "$pk"
    tls_pin = "$pin"
    log_level = "${ag.logLevel}"
    spool_cap_bytes = ${toString ag.spoolCapBytes}
    EOF
    chmod 0644 "$tmp"
    mv -f "$tmp" ${runDir}/agent.toml

    # Only for a first enrollment; the agent erases the file after the server accepts it.
    if [ -s "''${CREDENTIALS_DIRECTORY:-/nonexistent}/enroll-token" ] && [ ! -e /var/lib/cb-agent/enrolled ]; then
      install -m 0600 -o ${user} -g ${user} "$CREDENTIALS_DIRECTORY/enroll-token" ${runDir}/enroll-token
    fi
  '';
in {
  options.fmf.services.circuit-breaker.agent = {
    enable = mkBoolOpt false "Run the Circuit Breaker monitoring agent on this host.";
    package = mkOpt types.package pkgs.fmf.circuit-breaker-agent "The pinned agent package.";
    serverUrl = mkOpt types.str "" "Server base URL the agent dials (scheme + host[:port] only), e.g. https://topology.lan.example.com.";
    serverStaticPk = mkOpt (types.nullOr types.str) null ''
      The server's X25519 identity public key (64 hex characters). It is public.
      Read it on the server with `sudo circuit-breaker-admin agent-key`.
    '';
    serverStaticPkFile = mkOpt (types.nullOr types.str) null "Runtime file containing the same key (alternative to serverStaticPk).";
    tlsPin = mkOpt types.str "" "Base64 SHA-256 SPKI pin of the certificate the API serves itself (`server.tls.*`, self-signed); empty for a publicly trusted certificate.";
    tlsPinFile = mkOpt (types.nullOr types.str) null "Runtime file containing the pin (alternative to tlsPin).";
    logLevel = mkOpt (types.enum ["debug" "info" "warn" "error"]) "info" "Log level.";
    spoolCapBytes = mkOpt types.ints.positive 67108864 "Offline telemetry spool size.";
    enrollTokenFile = mkOpt (types.nullOr types.str) null ''
      Runtime path of a short-lived (max 24h) single-use enrollment token for unattended
      first enrollment. Delivered with LoadCredential, staged on tmpfs, erased by the
      agent after use. null = attended enrollment (approve the printed fingerprint in the UI).
    '';
    widenPingGroupRange = mkBoolOpt false ''
      Add all groups to net.ipv4.ping_group_range (unprivileged ICMP). NixOS already
      allows this by default on current kernels; enable only if you have narrowed the sysctl.
    '';
  };

  config = mkIf (cfg.enable && ag.enable) {
    assertions = [
      {
        assertion = builtins.match "https?://[^/]+/?" ag.serverUrl != null;
        message = "fmf.services.circuit-breaker.agent.serverUrl must be scheme://host[:port] with no path.";
      }
      {
        assertion = hasPrefix "https://" ag.serverUrl;
        message = "fmf.services.circuit-breaker.agent.serverUrl must be https:// (telemetry and enrollment tokens must not travel in clear text).";
      }
      {
        assertion = (ag.serverStaticPk == null) != (ag.serverStaticPkFile == null);
        message = "fmf.services.circuit-breaker.agent: set exactly one of serverStaticPk and serverStaticPkFile.";
      }
      {
        assertion = ag.serverStaticPk == null || builtins.match "[0-9a-f]{64}" ag.serverStaticPk != null;
        message = "fmf.services.circuit-breaker.agent.serverStaticPk must be 64 lowercase hex characters.";
      }
      {
        assertion = !(ag.tlsPin != "" && ag.tlsPinFile != null);
        message = "fmf.services.circuit-breaker.agent: set at most one of tlsPin and tlsPinFile.";
      }
      {
        assertion = all (f: f == null || !(hasPrefix builtins.storeDir f)) [ag.serverStaticPkFile ag.tlsPinFile ag.enrollTokenFile];
        message = "fmf.services.circuit-breaker.agent: file options must be runtime paths, not Nix store paths.";
      }
    ];

    # Fixed ids, so enabling the agent never renumbers the host's other dynamic
    # system accounts (see sync.nix).
    users.users.${user} = {
      isSystemUser = true;
      uid = 1502;
      group = user;
      description = "Circuit Breaker agent";
    };
    users.groups.${user}.gid = 1502;

    # `cb-agent status` is the supported way to read the fingerprint and link state.
    environment.systemPackages = [ag.package];

    # The binary reads this fixed path; the unit renders the target at start.
    environment.etc."circuit-breaker/agent.toml".source = "${runDir}/agent.toml";

    boot.kernel.sysctl = mkIf ag.widenPingGroupRange {
      "net.ipv4.ping_group_range" = mkDefault "0 2147483647";
    };

    systemd.services.cb-agent = {
      description = "Circuit Breaker agent";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      environment.CB_AGENT_STATE_DIR = "/var/lib/cb-agent";
      unitConfig = mkMerge [
        (mkIf (ag.serverStaticPkFile != null) {ConditionPathExists = ag.serverStaticPkFile;})
      ];
      serviceConfig =
        {
          ExecStartPre = "+${prepare}";
          ExecStart = "${ag.package}/bin/cb-agent";
          User = user;
          Group = user;
          StateDirectory = "cb-agent";
          StateDirectoryMode = "0700";
          RuntimeDirectory = "cb-agent";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "restart";
          Restart = "on-failure";
          RestartSec = "5s";

          # Hardening (the upstream unit, plus AF_NETLINK which the agent needs)
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
          SystemCallFilter = ["@system-service" "~@privileged"];
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
        }
        // optionalAttrs (ag.enrollTokenFile != null) {
          LoadCredential = ["enroll-token:${ag.enrollTokenFile}"];
        };
    };
  };
}
