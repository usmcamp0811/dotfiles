# Classification catalog for the Circuit Breaker inventory exporter.
#
# The exporter must not turn hundreds of low-level systemd units into diagram
# nodes, so a service is only reported when it is (a) listed here, or (b) an
# `fmf.services.<name>` module that declares a network port. This file is the
# "classification mechanism" for (a): it maps a service name to a kind, default
# ports, and optional health hints.
#
# Names are looked up in two namespaces:
#   - `fmf.services.<name>`   (this repository's service modules)
#   - `services.<name>`       (upstream NixOS), only when `upstream = true`
#
# Consumers can extend or override entries with the `extraCatalog` exporter
# option; `ignore` removes a name entirely.
{
  # kind: reverse-proxy | database | cache | dns | auth | secrets | scm |
  #       monitoring | storage | messaging | orchestrator | media |
  #       remote-access | application
  catalog = {
    traefik = {
      kind = "reverse-proxy";
      ports = [80 443];
      upstream = true;
    };
    nginx = {
      kind = "reverse-proxy";
      ports = [80];
      upstream = true;
    };
    caddy = {
      kind = "reverse-proxy";
      ports = [80 443];
      upstream = true;
    };
    haproxy = {
      kind = "reverse-proxy";
      ports = [];
      upstream = true;
    };

    postgresql = {
      kind = "database";
      ports = [5432];
      upstream = true;
      portPath = ["settings" "port"];
    };
    mysql = {
      kind = "database";
      ports = [3306];
      upstream = true;
    };
    mariadb = {
      kind = "database";
      ports = [3306];
    };
    mongodb = {
      kind = "database";
      ports = [27017];
      upstream = true;
    };
    qdrant = {
      kind = "database";
      ports = [6333];
    };
    chromadb = {
      kind = "database";
      ports = [8000];
    };

    redis = {
      kind = "cache";
      ports = [6379];
    };
    valkey = {
      kind = "cache";
      ports = [6379];
    };
    memcached = {
      kind = "cache";
      ports = [11211];
      upstream = true;
    };

    adguard = {
      kind = "dns";
      ports = [53];
    };
    adguardhome = {
      kind = "dns";
      ports = [53];
      upstream = true;
    };
    dnsmasq = {
      kind = "dns";
      ports = [53];
      upstream = true;
    };
    dnscrypt-proxy = {
      kind = "dns";
      ports = [];
    };
    unbound = {
      kind = "dns";
      ports = [53];
      upstream = true;
    };
    blocky = {
      kind = "dns";
      ports = [53];
      upstream = true;
    };

    authentik = {
      kind = "auth";
      ports = [9000];
    };
    keycloak = {
      kind = "auth";
      ports = [];
    };
    ldap-server = {
      kind = "auth";
      ports = [389];
    };

    vault = {
      kind = "secrets";
      ports = [8200];
    };
    vaultwarden = {
      kind = "secrets";
      ports = [];
    };

    gitea = {
      kind = "scm";
      ports = [3000];
    };
    gitlab = {
      kind = "scm";
      ports = [];
    };

    prometheus = {
      kind = "monitoring";
      ports = [9090];
      upstream = true;
      portPath = ["port"];
    };
    grafana = {
      kind = "monitoring";
      ports = [3000];
    };
    loki = {
      kind = "monitoring";
      ports = [3100];
    };
    netdata = {
      kind = "monitoring";
      ports = [19999];
    };
    uptime-kuma = {
      kind = "monitoring";
      ports = [4000];
    };
    ntopng = {
      kind = "monitoring";
      ports = [3000];
    };
    librenms = {
      kind = "monitoring";
      ports = [8080];
    };
    zeek = {
      kind = "monitoring";
      ports = [];
    };

    minio = {
      kind = "storage";
      ports = [9000];
    };
    garage = {
      kind = "storage";
      ports = [3900];
    };
    glusterfs = {
      kind = "storage";
      ports = [24007];
    };
    syncthing = {
      kind = "storage";
      ports = [8384];
    };
    attic = {
      kind = "storage";
      ports = [];
    };
    niks3 = {
      kind = "storage";
      ports = [5751];
    };

    apache-kafka = {
      kind = "messaging";
      ports = [9092];
    };
    zookeeper = {
      kind = "messaging";
      ports = [2181];
    };

    k3s = {
      kind = "orchestrator";
      ports = [6443];
      upstream = true;
    };
    circuit-breaker = {
      kind = "monitoring";
      ports = [8000];
    };
    k8s-control-plane = {
      kind = "orchestrator";
      ports = [6443];
    };

    jellyfin = {
      kind = "media";
      ports = [8096];
    };
    navidrome = {
      kind = "media";
      ports = [4533];
    };
    immich = {
      kind = "media";
      ports = [];
    };
  };

  # fmf.services names that never describe a network-facing service.
  ignore = [
    "crystal-forge"
    "vault-agent"
    "openssh"
    "microvm-healthcheck"
    "user-secrets"
    "secret-service"
    "borgbackup"
    "lynis"
    "vulnix"
    "promtail"
    "renew-pki"
    "attic-watch-store"
    "niks3-auto-upload"
    "nix-grpc-store"
    "nix-snapshotter"
    "wazuh-agent"
    "openwrt-backup"
    "entrypoint"
    "busybox"
    "example_postgresql"
  ];
}
