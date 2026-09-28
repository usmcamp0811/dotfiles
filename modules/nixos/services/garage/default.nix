{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.garage;

  garageEnvironmentFile = "/run/keys/environment/garage/garage.EnvFile";

  # Upstream `services.garage` defaults to `DynamicUser = true`, and only
  # auto-chowns `metadata_dir`/`data_dir` to that ephemeral UID when the
  # path textually starts with `/var/lib/garage` (via
  # `StateDirectory = "garage"`). That heuristic breaks the moment either
  # directory is -- or lives inside -- a *separately mounted* filesystem
  # (a dedicated ZFS dataset, a bind mount, etc), which is a very common
  # setup for Garage's often-large data_dir: mounting something on top of
  # a directory replaces its visible ownership with whatever the mounted
  # filesystem's own root inode has, regardless of any chown applied to
  # the mountpoint beforehand or its `/var/lib/garage` prefix. The result
  # is the same either way: Garage fails at startup with
  # "IO error: Permission denied" the moment it opens that directory.
  #
  # Sidestep this entirely with a static `garage` user/group: create and
  # chown `metadataDir` and every `dataDir` path ourselves via
  # `systemd.tmpfiles.rules` (which runs after local filesystems are
  # mounted, so this applies correctly even when one of them is a
  # separate mount), and run the unit as that fixed user instead of a
  # dynamic one. This is the only consumer of this module in either flake
  # at the time of writing, so there's no other host relying on
  # `DynamicUser` behavior here.
  dataDirPaths =
    if builtins.isList cfg.dataDir
    then map (d: d.path) cfg.dataDir
    else [cfg.dataDir];

  garageOwnedPaths = [cfg.metadataDir] ++ dataDirPaths;

  garageSettings =
    {
      metadata_dir = cfg.metadataDir;
      data_dir = cfg.dataDir;

      db_engine = cfg.dbEngine;
      replication_factor = cfg.replicationFactor;

      rpc_bind_addr = cfg.rpcBindAddress;

      s3_api =
        {
          api_bind_addr = cfg.s3ApiBindAddress;
          s3_region = cfg.region;
        }
        // optionalAttrs (cfg.s3RootDomain != null) {
          root_domain = cfg.s3RootDomain;
        };
    }
    // optionalAttrs (cfg.rpcPublicAddress != null) {
      rpc_public_addr = cfg.rpcPublicAddress;
    }
    // optionalAttrs (cfg.bootstrapPeers != []) {
      bootstrap_peers = cfg.bootstrapPeers;
    }
    // optionalAttrs cfg.web.enable {
      s3_web = {
        bind_addr = cfg.web.bindAddress;
        root_domain = cfg.web.rootDomain;
        index = cfg.web.index;
      };
    }
    // optionalAttrs cfg.admin.enable {
      admin = {
        api_bind_addr = cfg.admin.bindAddress;
        metrics_require_token = cfg.admin.metricsRequireToken;
      };
    }
    // cfg.settings;

  bucketPermissionsSubmodule = types.submodule {
    options = {
      read = mkBoolOpt true "Grant the key read access to the bucket.";
      write = mkBoolOpt true "Grant the key write access to the bucket.";
      owner =
        mkBoolOpt false
        "Grant the key owner (bucket administration) access.";
    };
  };

  bucketSubmodule = types.submodule ({name, ...}: {
    options = {
      bucketName =
        mkOpt types.str name
        "Name of the Garage bucket to idempotently create.";

      keyName =
        mkOpt types.str "${name}-key"
        "Name of the Garage API key to idempotently import and grant on this bucket.";

      permissions =
        mkOpt bucketPermissionsSubmodule {}
        "Permissions to grant keyName on this bucket.";

      vault-path =
        mkOpt types.str "secret/campground/garage/buckets/${name}"
        "Vault KV path holding access_key_id/secret_access_key for this bucket's key.";

      kvVersion = mkOption {
        type = types.enum ["v1" "v2"];
        default = "v2";
        description = "Vault KV store version.";
      };
    };
  });

  # Name of the systemd (and vault-agent) service that idempotently
  # bootstraps the cluster layout and any configured buckets/keys.
  provisionServiceName = "garage-provision";

  bucketEnvTemplateName = field: name: "${name}-${field}";

  # Path to a bucket's Vault-templated access-key-id/secret-access-key
  # file, as rendered by the garage-provision vault-agent service below.
  # This mirrors nixos-vault-service's own
  # `${environmentFilesRoot}${serviceName}/${name}.EnvFile` convention as
  # a plain string constant (rather than looking it up via
  # `config.fmf.services.vault-agent.services.garage-provision...path`),
  # since that attribute only exists once this module's own `config`
  # block below actually registers it -- something NixOS's module system
  # can force while evaluating unrelated options (e.g. checking for
  # unmatched definitions), even when this branch is otherwise inactive.
  bucketEnvPath = field: name: "/run/keys/environment/${provisionServiceName}/${bucketEnvTemplateName field name}.EnvFile";

  garageBin = "${cfg.package}/bin/garage";

  # Idempotently: (1) assign+apply a single-node cluster layout if this
  # node doesn't already have one, and (2) ensure every configured
  # bucket, its API key, and that key's permissions on the bucket exist.
  # Safe to run repeatedly -- every step checks current state via
  # `garage json-api` (which talks to the local node over RPC,
  # authenticated with GARAGE_RPC_SECRET sourced from
  # garageEnvironmentFile) before acting.
  provisionScript = pkgs.writeShellScript "garage-provision" ''
    set -euo pipefail

    set -a
    [ -f ${escapeShellArg garageEnvironmentFile} ] && . ${escapeShellArg garageEnvironmentFile}
    set +a

    GARAGE=${escapeShellArg garageBin}
    JQ=${escapeShellArg "${pkgs.jq}/bin/jq"}

    echo "garage-provision: waiting for the local Garage RPC to come up"
    for _ in $(seq 1 60); do
      if "$GARAGE" json-api GetClusterStatus >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    ${optionalString cfg.layout.enable ''
      node_id_override=${escapeShellArg (
        if cfg.layout.nodeId != null
        then cfg.layout.nodeId
        else ""
      )}
      zone=${escapeShellArg cfg.layout.zone}
      capacity_json=${
        if cfg.layout.gateway
        then "null"
        else toString cfg.layout.capacity
      }

      status="$("$GARAGE" json-api GetClusterStatus)"

      if [ -n "$node_id_override" ]; then
        node_id="$node_id_override"
      else
        node_count="$(echo "$status" | "$JQ" -r '.nodes | length')"
        if [ "$node_count" -ne 1 ]; then
          echo "garage-provision: refusing to auto-detect this node's id: the cluster has $node_count nodes (expected exactly 1). Set fmf.services.garage.layout.nodeId explicitly." >&2
          exit 1
        fi
        node_id="$(echo "$status" | "$JQ" -r '.nodes[0].id')"
      fi

      has_role="$(echo "$status" | "$JQ" -r --arg id "$node_id" '[.nodes[] | select(.id == $id) | .role][0] // empty')"
      if [ -z "$has_role" ]; then
        echo "garage-provision: assigning cluster layout to node $node_id"
        layout="$("$GARAGE" json-api GetClusterLayout)"
        version="$(echo "$layout" | "$JQ" -r '.version')"
        next_version=$((version + 1))
        update_body="$("$JQ" -n --arg id "$node_id" --arg zone "$zone" --argjson capacity "$capacity_json" \
          '{roles: [{id: $id, zone: $zone, capacity: $capacity, tags: []}]}')"
        "$GARAGE" json-api UpdateClusterLayout "$update_body" >/dev/null
        apply_body="$("$JQ" -n --argjson version "$next_version" '{version: $version}')"
        "$GARAGE" json-api ApplyClusterLayout "$apply_body" >/dev/null
      else
        echo "garage-provision: node $node_id already has a cluster layout role, skipping"
      fi
    ''}

    ${concatStringsSep "\n" (mapAttrsToList (name: bucket: ''
        bucket_name=${escapeShellArg bucket.bucketName}
        key_name=${escapeShellArg bucket.keyName}
        access_key_id_file=${escapeShellArg (bucketEnvPath "access-key-id" name)}
        secret_access_key_file=${escapeShellArg (bucketEnvPath "secret-access-key" name)}

        echo "garage-provision: ensuring bucket $bucket_name"
        get_bucket_body="$("$JQ" -n --arg alias "$bucket_name" '{globalAlias: $alias}')"
        if ! "$GARAGE" json-api GetBucketInfo "$get_bucket_body" >/dev/null 2>&1; then
          "$GARAGE" json-api CreateBucket "$get_bucket_body" >/dev/null
        fi

        access_key_id="$(cat "$access_key_id_file")"
        secret_access_key="$(cat "$secret_access_key_file")"

        echo "garage-provision: ensuring key $key_name"
        get_key_body="$("$JQ" -n --arg id "$access_key_id" '{id: $id}')"
        if ! "$GARAGE" json-api GetKeyInfo "$get_key_body" >/dev/null 2>&1; then
          import_body="$("$JQ" -n --arg id "$access_key_id" --arg secret "$secret_access_key" --arg name "$key_name" \
            '{accessKeyId: $id, secretAccessKey: $secret, name: $name}')"
          "$GARAGE" json-api ImportKey "$import_body" >/dev/null
        fi

        bucket_id="$("$GARAGE" json-api GetBucketInfo "$get_bucket_body" | "$JQ" -r '.id')"
        allow_body="$("$JQ" -n --arg bucket "$bucket_id" --arg key "$access_key_id" \
          --argjson read ${boolToString bucket.permissions.read} \
          --argjson write ${boolToString bucket.permissions.write} \
          --argjson owner ${boolToString bucket.permissions.owner} \
          '{bucketId: $bucket, accessKeyId: $key, permissions: {read: $read, write: $write, owner: $owner}}')"
        "$GARAGE" json-api AllowBucketKey "$allow_body" >/dev/null
        echo "garage-provision: bucket $bucket_name ready (key $key_name)"
      '')
      cfg.buckets)}
  '';
in {
  options.fmf.services.garage = with types; {
    enable = mkBoolOpt false "Enable Garage S3-compatible object storage.";

    package =
      mkOpt package pkgs.garage_2
      "Garage package to use.";

    metadataDir =
      mkOpt str "/var/lib/garage/meta"
      "Directory used to store Garage metadata.";

    dataDir =
      mkOpt (either str (listOf attrs)) "/var/lib/garage/data"
      "Directory or directories used to store Garage object data.";

    dbEngine =
      mkOpt str "lmdb"
      "Garage metadata database engine.";

    replicationFactor =
      mkOpt ints.positive 1
      "Number of copies Garage stores for each object.";

    region =
      mkOpt str "garage"
      "S3 region exposed by Garage.";

    rpcBindAddress =
      mkOpt str "0.0.0.0:3901"
      "Address used by Garage for cluster RPC traffic.";

    rpcPublicAddress =
      mkOpt (nullOr str) null
      "RPC address advertised to other Garage nodes.";

    bootstrapPeers =
      mkOpt (listOf str) []
      "Garage cluster peers used to bootstrap this node.";

    s3ApiBindAddress =
      mkOpt str "0.0.0.0:3900"
      "Address used by the Garage S3 API.";

    s3RootDomain =
      mkOpt (nullOr str) null
      "Optional root domain used for virtual-hosted S3 buckets.";

    openFirewall =
      mkBoolOpt true
      "Open the S3 API port in the firewall.";

    openRpcFirewall =
      mkBoolOpt false
      "Open the Garage cluster RPC port in the firewall.";

    logLevel =
      mkOpt
      (enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ])
      "info"
      "Garage log level.";

    settings =
      mkOpt attrs {}
      "Additional Garage settings merged into the generated configuration.";

    web = {
      enable =
        mkBoolOpt false
        "Enable Garage's S3 static website endpoint.";

      bindAddress =
        mkOpt str "0.0.0.0:3902"
        "Address used by the Garage S3 website endpoint.";

      rootDomain =
        mkOpt str ".web.garage"
        "Root domain used by the Garage S3 website endpoint.";

      index =
        mkOpt str "index.html"
        "Default index document for Garage S3 websites.";

      openFirewall =
        mkBoolOpt false
        "Open the S3 website endpoint in the firewall.";
    };

    admin = {
      enable =
        mkBoolOpt true
        "Enable the Garage administration and metrics endpoint.";

      bindAddress =
        mkOpt str "127.0.0.1:3903"
        "Address used by the Garage administration API.";

      metricsRequireToken =
        mkBoolOpt true
        "Require authentication for Garage metrics.";

      openFirewall =
        mkBoolOpt false
        "Open the Garage administration endpoint in the firewall.";
    };

    role-id =
      mkOpt str
      config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id.";

    secret-id =
      mkOpt str
      config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id.";

    vault-path =
      mkOpt str "secret/campground/garage"
      "Vault KV path containing Garage secrets.";

    kvVersion = mkOption {
      type = enum [
        "v1"
        "v2"
      ];
      default = "v2";
      description = "Vault KV store version.";
    };

    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "Vault server address.";
    };

    layout = {
      enable =
        mkBoolOpt true
        ''
          Idempotently assign and apply a cluster layout for this node at
          boot, if it does not already have one. Intended for single-node
          Garage deployments; for multi-node clusters, set layout.nodeId
          explicitly (auto-detection only works when the cluster has
          exactly one node) or manage the layout by hand instead.
        '';

      nodeId =
        mkOpt (nullOr str) null
        ''
          Garage node ID to assign a layout role to. Defaults to
          auto-detecting the sole node reported by the cluster status,
          which only works for single-node clusters.
        '';

      zone =
        mkOpt str "garage"
        "Zone (datacenter) name to assign this node to in the cluster layout.";

      capacity =
        mkOpt (nullOr ints.positive) null
        ''
          Storage capacity, in bytes, to assign this node in the cluster
          layout. Required unless gateway = true.
          Example: 100 * 1000 * 1000 * 1000 for 100 GB.
        '';

      gateway =
        mkBoolOpt false
        "Assign this node as a gateway (no storage capacity, API entry point only) instead of a storage node.";
    };

    buckets =
      mkOption {
        type = attrsOf bucketSubmodule;
        default = {};
        description = ''
          Garage buckets (and their API keys) to idempotently provision
          at boot: the bucket is created if missing, the key is imported
          from Vault-sourced credentials if missing, and the key is
          granted the configured permissions on the bucket. See also
          fmf.services.garage.layout, which must succeed first (a fresh
          node has no storage capacity until a layout is applied).
        '';
      };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !(hasAttr "rpc_secret" cfg.settings);
        message = ''
          fmf.services.garage.settings must not contain rpc_secret.
          Store Garage secrets in Vault instead.
        '';
      }
      {
        assertion =
          !cfg.web.enable || cfg.web.rootDomain != "";
        message = ''
          fmf.services.garage.web.rootDomain must be set when the S3
          website endpoint is enabled.
        '';
      }
      {
        assertion =
          !cfg.layout.enable || cfg.layout.gateway || cfg.layout.capacity != null;
        message = ''
          fmf.services.garage.layout.capacity must be set (or
          layout.gateway = true) when fmf.services.garage.layout.enable
          is true.
        '';
      }
    ];

    services.garage = {
      enable = true;
      package = cfg.package;
      logLevel = cfg.logLevel;

      settings = garageSettings;

      # Secrets are rendered at runtime by the FMF Vault Agent module.
      environmentFile = garageEnvironmentFile;
    };

    # See the comment on `garageOwnedPaths` above: always run Garage as a
    # static user and own its directories ourselves, since DynamicUser's
    # auto-chown can't be relied on once any of them is a separate mount.
    users.users.garage = {
      isSystemUser = true;
      group = "garage";
      description = "Garage Object Storage";
    };
    users.groups.garage = {};

    # `d` (not `Z`/recursive) deliberately: this only sets ownership/mode
    # on the directory itself, not on Garage's own file contents inside
    # it, and it re-applies on every boot after local filesystems (and
    # thus any separate data_dir mount) are up --
    # systemd-tmpfiles-setup.service runs after local-fs.target.
    systemd.tmpfiles.rules =
      map (p: "d ${p} 0750 garage garage - -") garageOwnedPaths;

    systemd.services.garage.serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";
    };

    networking.firewall.allowedTCPPorts =
      optionals cfg.openFirewall [
        3900
      ]
      ++ optionals cfg.openRpcFirewall [
        3901
      ]
      ++ optionals (cfg.web.enable && cfg.web.openFirewall) [
        3902
      ]
      ++ optionals (cfg.admin.enable && cfg.admin.openFirewall) [
        3903
      ];

    fmf.services.vault-agent.services.garage = {
      settings = {
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

      secrets.environment = {
        change-action = "restart";

        templates.garage = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            GARAGE_RPC_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.rpc_secret }}{{ else }}{{ .Data.data.rpc_secret }}{{ end }}'
            ${optionalString cfg.admin.enable ''
              GARAGE_ADMIN_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.admin_token }}{{ else }}{{ .Data.data.admin_token }}{{ end }}'
            ''}${optionalString (cfg.admin.enable && cfg.admin.metricsRequireToken) ''
              GARAGE_METRICS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.metrics_token }}{{ else }}{{ .Data.data.metrics_token }}{{ end }}'
            ''}{{ end }}
          '';
        };
      };
    };

    # Idempotently bootstrap the cluster layout and any configured
    # buckets/keys. Runs as the `garage` user so it can read the same
    # garageEnvironmentFile (GARAGE_RPC_SECRET) the daemon itself uses,
    # and so vault-agent chowns the bucket credential files below to a
    # user that can actually read them.
    systemd.services.${provisionServiceName} = mkIf (cfg.layout.enable || cfg.buckets != {}) {
      description = "Idempotently configure the Garage cluster layout, buckets, and API keys";
      wantedBy = ["multi-user.target"];
      after = ["garage.service"];
      wants = ["garage.service"];
      requires = ["garage.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "garage";
        Group = "garage";
        ExecStart = "${provisionScript}";
      };
    };

    fmf.services.vault-agent.services.${provisionServiceName} =
      mkIf (cfg.layout.enable || cfg.buckets != {}) {
        settings = {
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

        secrets.environment = {
          change-action = "restart";

          templates =
            mapAttrs'
            (name: bucket:
              nameValuePair (bucketEnvTemplateName "access-key-id" name) {
                text = ''
                  {{ with secret "${bucket.vault-path}" }}{{ if eq "${bucket.kvVersion}" "v1" }}{{ .Data.access_key_id }}{{ else }}{{ .Data.data.access_key_id }}{{ end }}{{ end }}
                '';
              })
            cfg.buckets
            // mapAttrs'
            (name: bucket:
              nameValuePair (bucketEnvTemplateName "secret-access-key" name) {
                text = ''
                  {{ with secret "${bucket.vault-path}" }}{{ if eq "${bucket.kvVersion}" "v1" }}{{ .Data.secret_access_key }}{{ else }}{{ .Data.data.secret_access_key }}{{ end }}{{ end }}
                '';
              })
            cfg.buckets;
        };
      };
  };
}
