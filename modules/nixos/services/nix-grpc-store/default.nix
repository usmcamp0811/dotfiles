{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.nix-grpc-store;
  host = config.networking.hostName;

  # Where certificates live on disk. /var/lib/nix-grpc-store is also one of
  # the default lookup locations for the grpc:// client (client.crt/client.key).
  certDir = "/var/lib/nix-grpc-store";

  # nixos-vault-service renders `secrets.file.files.<name>` here (its
  # `${secretFilesRoot}${name}` convention), inside the sidecar's private
  # /tmp that the "infected" unit joins. Plain constant for the same reason as
  # fmf.services.niks3: looking it up through fmf.services.vault-agent would
  # force an attribute that only exists once this module's config registers it.
  vaultFile = name: "/tmp/detsys-vault/${name}";

  # The oneshot that installs certificates. Must exactly match the name of the
  # vault-agent service below: nixos-vault-service only wires the sidecar
  # (ordering + shared PrivateTmp) into a unit with the same name.
  certsUnit = "nix-grpc-store-certs";

  farmHost = head (splitString ":" cfg.farm.address);
  nodeAddr = "${cfg.ip}:${toString cfg.node.port}";
  lbListen = "[::]:${toString cfg.lb.port}";

  wantsCerts = cfg.node.enable || cfg.lb.enable || cfg.client.useFarm;

  # The PKI mount, derived from the issue path ("<mount>/issue/<role>"), and
  # where its CA certificate is read from. pkiCert's `.CA` is NOT trusted as the
  # trust anchor on its own: a mount can hand back a stale certificate for the
  # CA key (we hit an expired self-signed copy while leaves were being issued
  # fine). The CA read from here is tried first and, either way, a CA is only
  # installed if it actually validates the issued leaf (see certsScript).
  pkiMount = head (splitString "/issue/" cfg.pki.path);
  caPath =
    if cfg.pki.caPath != null
    then cfg.pki.caPath
    else "${pkiMount}/cert/ca";

  vaultSecretTemplate = path: kvVersion: field: ''
    {{ with secret "${path}" }}{{ if eq "${kvVersion}" "v1" }}{{ .Data.${field} }}{{ else }}{{ .Data.data.${field} }}{{ end }}{{ end }}
  '';

  # ---------------------------------------------------------------------------
  # Certificates
  #
  # One Vault PKI issuance per identity, rendered as ONE file:
  #     <issuing CA>
  #     #--CERT--
  #     <leaf certificate>
  #     #--KEY--
  #     <private key>
  # consul-template keys a pkiCert dependency by (path, args, *destination
  # file*), so two templates calling pkiCert would each issue their own
  # certificate and a cert/key pair rendered from separate templates would not
  # match. One template per identity avoids that; the oneshot below splits it.
  # (pkiCert returns {Cert, Key, CA}; Vault's docs show `.Data.Cert` in one
  # example, but that is the `secret` function's shape, not pkiCert's.)
  # ---------------------------------------------------------------------------
  certMarker = "#--CERT--";
  keyMarker = "#--KEY--";

  pkiTemplate = {
    cn,
    ipSans ? null,
    altNames ? [],
  }: let
    params =
      ["common_name=${cn}" "ttl=${cfg.pki.ttl}"]
      ++ optional (ipSans != null) "ip_sans=${ipSans}"
      ++ optional (altNames != []) "alt_names=${concatStringsSep "," altNames}";
    args = concatMapStringsSep " " (p: "\"${p}\"") params;
  in "{{ with pkiCert \"${cfg.pki.path}\" ${args} }}{{ .CA }}${certMarker}\n{{ .Cert }}${keyMarker}\n{{ .Key }}{{ end }}\n";

  # id -> { enable, cn, ... , key ownership }. The client name `ci-*` and the
  # `worker-*` / `lb-*` names are what the daemons' accessRules match on.
  identities = {
    client = {
      enable = cfg.client.useFarm;
      tpl = pkiTemplate {cn = "ci-${host}";};
      keyOwner = "root";
      keyGroup = "root";
      keyMode = "0600";
    };
    node = {
      enable = cfg.node.enable;
      tpl = pkiTemplate {
        cn = "worker-${host}";
        ipSans = cfg.ip;
      };
      keyOwner = "nix-grpc-daemon";
      keyGroup = "nix-grpc-daemon";
      keyMode = "0600";
    };
    lb = {
      enable = cfg.lb.enable;
      tpl = pkiTemplate {
        cn = "lb-${host}";
        ipSans = cfg.ip;
        altNames = optional (!(isIPv4 farmHost)) farmHost;
      };
      # envoy runs as a DynamicUser, so it reads its key through this group.
      keyOwner = "root";
      keyGroup = "nix-grpc-certs";
      keyMode = "0640";
    };
  };
  enabledIdentities = filterAttrs (_: v: v.enable) identities;

  isIPv4 = s: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" s != null;

  certsScript = ''
    set -euo pipefail
    umask 077
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    install -d -m 0755 ${certDir}

    # atomic replace in the same directory: envoy/the daemons watch this
    # directory and reload certificates when files are renamed into it.
    place() { # src mode owner group dest
      install -m "$2" -o "$3" -g "$4" "$1" "$5.new"
      mv -f "$5.new" "$5"
    }

    # CA certificate read straight from the PKI mount (preferred trust anchor).
    fetched="$work/fetched.ca"
    if [ -s "${vaultFile "farm-ca.pem"}" ]; then
      cp "${vaultFile "farm-ca.pem"}" "$fetched"
    fi

    rc=0
    handle() { # id key_owner key_group key_mode
      local id="$1" owner="$2" group="$3" mode="$4"
      local in="${vaultFile "farm-"}$id.pem"
      if [ ! -s "$in" ]; then
        echo "$id: no certificate rendered by vault-agent yet" >&2
        rc=1
        return 0
      fi

      awk -v ca="$work/$id.ca" -v cert="$work/$id.leaf" -v key="$work/$id.key" '
        BEGIN { out = ca }
        $0 == "${certMarker}" { out = cert; next }
        $0 == "${keyMarker}"  { out = key;  next }
        { print > out }
      ' "$in"

      # Guard against ever installing a mismatched pair.
      if [ "$(openssl x509 -noout -pubkey -in "$work/$id.leaf")" != "$(openssl pkey -pubout -in "$work/$id.key")" ]; then
        echo "$id: certificate and private key do not match, not installing" >&2
        rc=1
        return 0
      fi

      # Pick a CA that really validates this leaf (signature AND validity
      # dates). Prefer the one read from the mount; fall back to pkiCert's.
      ca=""
      for cand in "$fetched" "$work/$id.ca"; do
        [ -s "$cand" ] || continue
        if openssl verify -CAfile "$cand" "$work/$id.leaf" >/dev/null 2>&1; then
          ca="$cand"
          break
        fi
      done
      if [ -z "$ca" ]; then
        echo "$id: no available CA validates the issued certificate, not installing:" >&2
        for cand in "$fetched" "$work/$id.ca"; do
          [ -s "$cand" ] || continue
          echo "  tried $(basename "$cand"): $(openssl x509 -noout -subject -enddate -in "$cand" | tr '\n' ' ')" >&2
          openssl verify -CAfile "$cand" "$work/$id.leaf" 2>&1 | sed 's/^/    /' >&2 || true
        done
        rc=1
        return 0
      fi

      cat "$work/$id.leaf" "$ca" > "$work/$id.chain"
      place "$work/$id.key"   "$mode" "$owner" "$group" ${certDir}/$id.key
      place "$work/$id.chain" 0644    root     root     ${certDir}/$id.crt
      place "$ca"             0644    root     root     ${certDir}/ca.crt
      echo "$id: installed $(openssl x509 -noout -subject -enddate -in "$work/$id.leaf" | tr '\n' ' ')"
    }

    ${concatStringsSep "\n" (mapAttrsToList (id: v: "handle ${id} ${v.keyOwner} ${v.keyGroup} ${v.keyMode}") enabledIdentities)}

    exit $rc
  '';

  vaultAgentSettings = {
    vault.address = cfg.vault-address;

    auto_auth = {
      method = [
        {
          type = "approle";

          config = {
            role_id_file_path = cfg.role-id;
            secret_id_file_path = cfg.secret-id;
            remove_secret_id_file_after_reading = false;
          };
        }
      ];
    };
  };
in {
  # Already part of fmf's own `systems.modules.nixos`, but downstream flakes
  # (e.g. Campground) only get fmf's *own* modules, so import it here too
  # (same pattern as fmf.services.niks3). Duplicate imports of the same file
  # are de-duplicated by the module system.
  imports = [inputs.nix-grpc-store.nixosModules.default];

  options.fmf.services.nix-grpc-store = with types; {
    ip =
      mkOpt (nullOr str) null
      "This host's LAN IPv4 address. Required for node/lb: it is the address the balancer dials (advertise) and goes in the certificate's IP SANs.";

    client = {
      enable =
        mkBoolOpt false
        "Load the grpc:// store plugin into nix, so this host can use grpc:// stores. Harmless when unused: on a Nix version mismatch the loader disables grpc:// with a warning instead of failing.";

      useFarm =
        mkBoolOpt false
        ''
          Also send builds to the farm: issues this host a client certificate
          (CN ci-<hostname>) and adds the farm as a Nix build machine. That
          certificate is granted the `trusted` role on the builders, which is
          effectively root-level build access, so enable it only on hosts you
          trust with that.
        '';

      systems =
        mkOpt (listOf str) ["x86_64-linux"]
        "Systems to send to the farm (one build machine entry per system).";

      maxJobs = mkOpt int 32 "Concurrent builds Nix may send to the farm.";

      supportedFeatures =
        mkOpt (listOf str) ["big-parallel" "kvm" "nixos-test"]
        "Features advertised for the farm build machines.";
    };

    node = {
      enable =
        mkBoolOpt false
        "Run nix-grpc-daemon as a farm node. Builders run builds; the scheduler role keeps the queue. Every node also needs `ip`.";

      roles =
        mkOpt (listOf (enum ["builder" "scheduler"])) ["builder"]
        "Roles of this node. Give `scheduler` to exactly one node (the one farm.schedulerAddress points at).";

      port = mkOpt port 50052 "Port the daemon listens on.";

      openFirewall =
        mkBoolOpt true
        "Open the node port in the firewall. Access is still gated by mTLS + accessRules.";

      minFree =
        mkOpt str "20G"
        "Take no new builds below this much free disk space.";

      maxJobs =
        mkOpt (nullOr int) null
        "Concurrent builds (1-63). Defaults to nix.settings.max-jobs.";
    };

    lb = {
      enable =
        mkBoolOpt false
        "Run the envoy balancer clients talk to. Needs `ip`; put it on the same host as the scheduler.";

      port = mkOpt port 50051 "Port the balancer listens on.";

      systems =
        mkOpt (nonEmptyListOf str) ["x86_64-linux"]
        "Systems the farm builds for.";
    };

    farm = {
      address =
        mkOpt str "farm.lan.aicampground.com:443"
        "host:port of the farm as clients see it. Defaults to the LAN traefik TCP/SNI passthrough in front of the envoy balancer (lb.port).";

      schedulerAddress =
        mkOpt str "10.8.0.176:50052"
        "IP:port of the (single) scheduler node, i.e. its `advertise`. Builders connect here and the balancer reads the builder list from it.";
    };

    pki = {
      path =
        mkOpt str "campground-pki/issue/grpc-farm"
        "Vault PKI issue path (mount/issue/role) used to mint the mTLS certificates.";

      caPath =
        mkOpt (nullOr str) null
        ''
          Vault path the PKI mount's CA certificate is read from (field
          "certificate"). Defaults to "<mount>/cert/ca", with <mount> taken from
          `path`. A CA is only ever installed if it validates the issued leaf.
        '';

      ttl =
        mkOpt str "72h"
        "Lifetime of issued certificates. vault-agent renews them at ~90% of this.";
    };

    niks3 = {
      url = mkOpt str "https://niks3.lan.aicampground.com" "niks3 server URL nodes publish build outputs to.";

      cacheUrl = mkOpt str "https://niks3.lan.aicampground.com" "Binary cache nodes substitute from.";

      vault-path =
        mkOpt str "secret/campground/niks3"
        "Vault KV path holding niks3's API token (the same secret fmf.services.niks3 uses).";

      vault-field = mkOpt str "api_token" "Field within vault-path holding the API token.";
    };

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id.";

    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id.";

    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV store version.";
    };

    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "Vault server address.";
    };
  };

  config = mkMerge [
    # ---- client plugin ------------------------------------------------------
    (mkIf (cfg.client.enable || cfg.client.useFarm) {
      programs.nix-grpc-store.enable = true;
    })

    # ---- shared: certificate pipeline --------------------------------------
    (mkIf wantsCerts {
      assertions = [
        {
          assertion = config.fmf.services.vault-agent.enable;
          message = "fmf.services.nix-grpc-store needs fmf.services.vault-agent.enable = true (certificates are issued through Vault).";
        }
        {
          assertion = !(cfg.node.enable || cfg.lb.enable) || cfg.ip != null;
          message = "fmf.services.nix-grpc-store.ip must be set when node or lb is enabled.";
        }
      ];

      users.groups.nix-grpc-certs = {};

      systemd.services.${certsUnit} = {
        description = "Install nix-grpc-store mTLS certificates issued by Vault PKI";
        wantedBy = ["multi-user.target"];
        path = [pkgs.openssl pkgs.gawk pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = certsScript;
      };

      fmf.services.vault-agent.services.${certsUnit} = {
        settings = vaultAgentSettings;

        # A renewed certificate re-renders the file, which restarts the oneshot
        # (= reinstalls). The daemons/envoy pick renewed files up from disk.
        secrets.file = {
          change-action = "restart";
          files =
            (mapAttrs' (id: v: nameValuePair "farm-${id}.pem" {text = v.tpl;}) enabledIdentities)
            // {
              # The mount's CA certificate (unlike the leaves, this is public).
              "farm-ca.pem".text = ''
                {{ with secret "${caPath}" }}{{ .Data.certificate }}{{ end }}
              '';
            };
        };
      };
    })

    # ---- farm client (this host sends builds to the farm) ------------------
    (mkIf cfg.client.useFarm {
      # remote-builders also sets this (to hasBuilders); force it on.
      nix.distributedBuilds = mkForce true;
      nix.buildMachines =
        map (system: {
          hostName = "grpc://${cfg.farm.address}?system=${system}&ca-cert=${certDir}/ca.crt&client-cert=${certDir}/client.crt&client-key=${certDir}/client.key";
          protocol = null;
          inherit system;
          inherit (cfg.client) supportedFeatures maxJobs;
        })
        cfg.client.systems;
    })

    # ---- farm node ----------------------------------------------------------
    (mkIf cfg.node.enable {
      assertions = [
        {
          assertion = config.fmf.cache.niks3.publicKey != null;
          message = "fmf.services.nix-grpc-store.node needs fmf.cache.niks3.publicKey (nodes verify and publish through the niks3 cache).";
        }
        {
          assertion = cfg.node.roles != [];
          message = "fmf.services.nix-grpc-store.node.roles must not be empty.";
        }
      ];

      networking.firewall.allowedTCPPorts = optional cfg.node.openFirewall cfg.node.port;

      services.nix-grpc-daemon = {
        enable = true;
        listen = "[::]:${toString cfg.node.port}";
        advertise = nodeAddr;
        inherit (cfg.node) roles minFree maxJobs;
        # A scheduler node schedules onto itself; everyone else reports to it.
        scheduler =
          if elem "scheduler" cfg.node.roles
          then null
          else cfg.farm.schedulerAddress;
        # Farm nodes must be plain services: a socket-activated idle node would
        # never register with the scheduler.
        idleTimeout = null;

        tls = {
          certFile = "${certDir}/node.crt";
          keyFile = "${certDir}/node.key";
          clientCaFile = "${certDir}/ca.crt";
        };

        # The balancer's identity is forwarded to nodes; clients (ci-*), other
        # nodes (worker-*) and the balancer (lb-*) all need `trusted` (the build
        # hook uploads locally-built, unsigned paths; nodes drive the scheduler).
        trustedProxies = ["lb-*"];
        accessRules = [
          {
            cn = "ci-*";
            role = "trusted";
          }
          {
            cn = "worker-*";
            role = "trusted";
          }
          {
            cn = "lb-*";
            role = "trusted";
          }
        ];

        niks3 = {
          package = config.services.niks3.package;
          url = cfg.niks3.url;
          tokenFile = vaultFile "niks3-token";
          cacheUrl = cfg.niks3.cacheUrl;
          publicKeys = [config.fmf.cache.niks3.publicKey];
        };
      };

      # Certificates are installed by the oneshot above.
      systemd.services.nix-grpc-daemon = {
        after = ["${certsUnit}.service"];
        wants = ["${certsUnit}.service"];
      };

      # nix-grpc-daemon.service is "infected" by name: the token is rendered
      # into the sidecar's namespace the daemon joins, and chowned to the
      # unit's own user. The daemon re-reads the token file on change.
      fmf.services.vault-agent.services.nix-grpc-daemon = {
        settings = vaultAgentSettings;

        secrets.file = {
          change-action = "none";
          files."niks3-token".text =
            vaultSecretTemplate cfg.niks3.vault-path cfg.kvVersion cfg.niks3.vault-field;
        };
      };
    })

    # ---- balancer -----------------------------------------------------------
    (mkIf cfg.lb.enable {
      networking.firewall.allowedTCPPorts = [cfg.lb.port];

      services.nix-grpc-farm-lb = {
        enable = true;
        listen = lbListen;
        inherit (cfg.lb) systems;
        scheduler = cfg.farm.schedulerAddress;

        tls = {
          certFile = "${certDir}/lb.crt";
          keyFile = "${certDir}/lb.key";
          clientCaFile = "${certDir}/ca.crt";
          # The same identity is presented to the nodes (their trustedProxies
          # is lb-*), and the nodes are verified against the same private CA.
          upstream = {
            certFile = "${certDir}/lb.crt";
            keyFile = "${certDir}/lb.key";
            caFile = "${certDir}/ca.crt";
          };
        };
      };

      systemd.services.envoy = {
        after = ["${certsUnit}.service"];
        wants = ["${certsUnit}.service"];
        serviceConfig.SupplementaryGroups = ["nix-grpc-certs"];
      };
    })
  ];
}
