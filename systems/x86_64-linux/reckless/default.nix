{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
with lib;
with lib.campground; let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in {
  imports = [./hardware.nix];
  boot.kernelParams = ["pcie_port_pm=off" "pcie_aspm.policy=performance"];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  systemd.services.proton-socat-smtp = {
    description = "Socat Service for Proton Bridge SMTP Port Forwarding";
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:587,fork TCP4:127.0.0.1:1025";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
  };

  systemd.services.proton-socat-imap = {
    description = "Socat Service for Proton Bridge IMAP Port Forwarding";
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:143,fork TCP4:127.0.0.1:1143";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
  };
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker"];
      uid = 10000;
    };

    security.gpg = enabled;
    suites = {
      lan-hosting = {
        enable = true;
        interface = "eno1";
        # log-to-kafka = true;
      };
      # kubernetes = {
      #   enable = true;
      #   role = "worker";
      #   interface = "eno1";
      # };
      development = enabled;
    };
    desktop.addons.rkvm = {
      enableServer = true;
      # enableClient = true;
      # address = "ata-nuc:5258";
    };

    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        hostId = "13ec383b";
      };
    };

    nix = {
      extra-substituters = {
        "https://nix-gaming.cachix.org" = {
          key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
        };
      };
    };

    apps = {steam = enabled;};
    nfs.client = {enable = true;};

    hardware = {
      ckb-next = enabled;
      via = enabled;
      ups.cp1500 = {enable = true;};
      nvidia = {
        enable = true;
      };
      bluetooth = enabled;
    };

    services = {
      crystal-forge-website = enabled;
      crystal-forge = {
        enable = true;
        # log_level = "debug";

        # Cache configuration for your Attic cache
        cache = {
          # cache_type = "Attic";
          # attic_cache_name = "campground";
          # push_to = "https://attic.aicampground.com/campground";
          cache_type = "S3";
          push_to = "s3://nix-cache?endpoint=https://s3-api.lan.aicampground.com&region=us-east-1";
          s3_region = "us-east-1";
          push_after_build = true;
          parallel_uploads = 3;
          max_retries = 5;
          retry_delay_seconds = 5;
        };

        # Build configuration to enable cache pushing
        build = {
          enable = true;
          cores = 12;
          max_jobs = 4;
          max_concurrent_derivations = 1;
          systemd_memory_max = "32G";
          systemd_cpu_quota = 1000; # 10 cores per build
          use_substitutes = true;
          poll_interval = "1s";
          sandbox = true;
          # systemd_properties = [
          #   "Environment=ATTIC_SERVER_URL=https://attic.aicampground.com/campground"
          #   "Environment=ATTIC_REMOTE_NAME=campground"
          #   # Add ATTIC_TOKEN if you have it statically, or let vault handle it
          # ];
        };

        flakes.watched = [
          {
            name = "dotfiles";
            repo_url = "https://gitlab.com/usmcamp0811/dotfiles?ref=nixos";
            auto_poll = true;
            initial_commit_depth = 10;
          }
          {
            name = "boterf-nix-configurations";
            repo_url = "https://gitlab.com/michaelboterf/nix-configurations";
            auto_poll = true;
            initial_commit_depth = 10;
          }
        ];

        environments = [
          {
            name = "wifi";
            description = "Computers that get on wifi";
            is_active = true;
            risk_profile = "MEDIUM";
            compliance_level = "NONE";
          }
          {
            name = "lan";
            description = "Computers that get are wired";
            is_active = true;
            risk_profile = "LOW";
            compliance_level = "NONE";
          }
          {
            name = "boterf-net";
            description = "Computers that are on Boterf's Network";
            is_active = true;
            risk_profile = "LOW";
            compliance_level = "NONE";
          }
        ];

        systems = [
          {
            hostname = "txboterf-nzxt-gaming";
            public_key = "UX6i4J8llCDTJICZ6FLve2yx5RgEo/5yttvEuuRa06w=";
            environment = "boterf-net";
            flake_name = "boterf-nix-configurations";
          }
          {
            hostname = "gray";
            public_key = "hUwxCZUFydwDjf8BMyXLyMiI33PrKvhfDRj60OkisdY=";
            environment = "wifi";
            flake_name = "dotfiles";
            deployment_policy = "auto_latest";
          }
          {
            hostname = "reckless";
            public_key = "SKYgYiwK0vMwK3sJP6R53z0gbtOVSWOmJ33WT4AbCQ8=";
            environment = "lan";
            flake_name = "dotfiles";
            deployment_policy = "auto_latest";
          }
          {
            hostname = "webb";
            public_key = "ZJBA2GS03P+Q2mhUAbjfjFILQ57yGChjXmRdL6Xfang=";
            environment = "lan";
            flake_name = "dotfiles";
          }
          {
            hostname = "lucas";
            public_key = "OMxvf/rZmi8PZJOpVxjbPHDaX+BmJqp8FUOoosWJ7qY=";
            environment = "lan";
            flake_name = "dotfiles";
            deployment_policy = "auto_latest";
          }
          {
            hostname = "chesty";
            public_key = "Asu0Fl8SsM9Pd/woHt5qkvBdCbye6j2Q2M/qDmnFUjc=";
            environment = "lan";
            flake_name = "dotfiles";
            deployment_policy = "auto_latest";
          }
          {
            hostname = "daly";
            public_key = "JhjP4LK72nuTQJ6y7pcYjoTtfrY86BpJBi9WeolcpKY=";
            environment = "lan";
            flake_name = "dotfiles";
            deployment_policy = "auto_latest";
          }
          {
            hostname = "ermy";
            public_key = "z9FINYnz2IPPaECHZbTae5prPFUE/ubAT+4HHLPSq7I=";
            environment = "lan";
            flake_name = "dotfiles";
          }
          {
            hostname = "butler";
            public_key = "rbMIke0a5emtaPc7MKgwqEn/UL3e0yyKUn5zHy3Ct/c=";
            environment = "lan";
            flake_name = "dotfiles";
          }
          {
            hostname = "mattis";
            public_key = "vfRbvu/rl1c9+zqMRHzCKMrqpchahyf5qFDUaJyj3eg=";
            environment = "lan";
            flake_name = "dotfiles";
          }
        ];

        server = {
          enable = true;
          host = "0.0.0.0";
          port = 3444;
        };

        # Database configuration (using defaults)
        database = {
          host = "localhost";
          user = "crystal_forge";
          name = "crystal_forge";
          port = 5432;
        };

        # Enable local database management if needed
        local-database = true;

        # CVE scanning configuration
        vulnix = {
          timeout = "10m";
          max_retries = 3;
          poll_interval = "5m";
        };
      };
      glusterfs = {
        enable = true;
        # peers = ["webb"];
        peers = ["reckless" "lucas"];
        volumes = [
          {
            name = "kubernetes";
            brickDirs = ["/glusterfs/kubernetes"];
            replicaCount = 2;
            transport = "tcp";
          }
        ];
      };

      searx = {
        enable = true;
        port = 3249;
      };
      k3s = {
        enable = true;
        role = "agent";
        serverAddr = "10.8.0.197";
      };
      macos-vm = {
        enable = true;
        diskSizeBytes = 161061273600;
      };
      navidrome = enabled;
      matt-camp-website = enabled;
      cac = enabled;
      netbird.client = enabled;
      mealie = enabled;

      # grafana = {
      #   enable = true;
      #   datasources = [
      #     {
      #       name = "Prometheus";
      #       type = "prometheus";
      #       access = "proxy";
      #       url = "http://webb:9011";
      #     }
      #     {
      #       name = "Loki";
      #       type = "loki";
      #       access = "proxy";
      #       url = "http://webb:3030";
      #     }
      #     {
      #       name = "Firefly Postgres";
      #       type = "postgres";
      #       access = "proxy"; # Grafana handles the queries via the proxy
      #       host = "/run/postgresql";
      #       user = "firefly"; # The correct user
      #       database = "firefly"; # The firefly database
      #       jsonData.sslmode = "disable";
      #     }
      #   ];
      # };
      spark = {
        enable = true;
        port = 8081;
        master = {
          extraEnvironment = {
            SPARK_MASTER_OPTS = "-Dspark.deploy.defaultCores=5";
            SPARK_MASTER_WEBUI_PORT = "8181";
          };
          bind = "0.0.0.0";
          enable = true;
          restartIfChanged = true;
        };
        worker = {
          master = "spark://reckless:7077";
          workDir = "/var/lib/spark";
          enable = true;
          extraEnvironment = {
            SPARK_WORKER_CORES = "4";
            SPARK_WORKER_MEMORY = "4g";
          };
          restartIfChanged = true;
        };
        logDir = "/var/log/spark";
      };
      campground-blog = enabled;
      qdrant = {
        enable = true;
        settings.service.host = "0.0.0.0";
      };
      open-webui = enabled;
      ollama = {
        enable = true;
        acceleration = "cuda";
        # host = "0.0.0.0";
      };
      file-share = enabled;
      ldap-client = {enable = mkForce false;};
      attic-watch-store = enabled;
      gitlab-runner = enabled;
      # hadoop = {
      #   enable = true;
      #   yarnSite = { "yarn.nodemanager.hostname" = "reckless"; };
      #   # hdfs = {
      #   #   datanode.enable = true;
      #   #   datanode.restartIfChanged = true;
      #   #   datanode.openFirewall = true;
      #   #   datanode.extraFlags = [ ];
      #   #   datanode.extraEnv = { };
      #   #   datanode.dataDirs = [ ];
      #   #
      #   #   journalnode.enable = true;
      #   #   journalnode.restartIfChanged = true;
      #   #   journalnode.openFirewall = true;
      #   #   journalnode.extraFlags = [ ];
      #   #   journalnode.extraEnv = { };
      #   #
      #   #   httpfs.enable = true;
      #   # };
      #   yarn = {
      #     nodemanager.enable = true;
      #     nodemanager.useCGroups = false;
      #     nodemanager.restartIfChanged = true;
      #     nodemanager.resource.memoryMB = null;
      #     nodemanager.resource.maximumAllocationVCores = null;
      #     nodemanager.resource.maximumAllocationMB = null;
      #     nodemanager.resource.cpuVCores = null;
      #     nodemanager.openFirewall = true;
      #     nodemanager.localDir = null;
      #     nodemanager.extraFlags = [ ];
      #     nodemanager.extraEnv = { };
      #     nodemanager.addBinBash = true;
      #   };
      # };
      attic = {
        enable = true;
        settings = {
          listen = "[::]:8082";
          database = {
            url = "postgres://atticd@localhost/atticd?host=/run/postgresql/";
          };
          storage = {
            type = "local";
            path = "/var/lib/atticd";
          };
          chunking = {
            "nar-size-threshold" =
              65536; # chunk files that are 64 KiB or larger
            "min-size" = 16384; # 16 KiB
            "avg-size" = 65536; # 64 KiB
            "max-size" = 262144; # 256 KiB
          };
          compression = {type = "zstd";};
          garbage-collection = {interval = "144 hours";};
        };
      };

      postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        extraPlugins = [pkgs.postgresql16Packages.timescaledb pkgs.postgresql16Packages.pg_cron];
        enableTCPIP = true;
        settings = {
          shared_preload_libraries = "pg_cron,timescaledb";
          "cron.database_name" = "postgres";
          max_connections = 200;
          log_statement = "all"; # or "none", "ddl", "mod"
        };
        databases = [
          {
            name = "atticd";
            user = "atticd";
          }
        ];
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = [
          "local all root trust"
          "local all postgres peer"
          "local atticd atticd trust"
          "host  crystal_forge  grafana  10.8.0.0/24  trust"
          "host  crystal_forge  crystal_forge  127.0.0.1/32  trust"
          "host  postgres  crystal_forge  127.0.0.1/32  trust"
          "host  postgres  crystal_forge  ::1/128       trust"
          "host  crystal_forge   crystal_forge   ::1/128     trust"
          # "host  campgroundai  campgroundai  0.0.0.0/0 md5"
          "host  all  all  0.0.0.0/0  reject"
          "host  all  all  ::0/0  reject"
        ];
      };
      nix-snapshotter = enabled;
      flakeforge = enabled;
      zfs-key-server = {
        enable = true;
        interface = "eno1";
        tang-servers = [
          # "http://webb:1234"
          # "http://lucas:1234"
          "http://chesty:1234"
          "http://mattis:1234"
          "http://daly:1234"
          # "http://ermy:1234"
        ];
      };

      user-secrets = {
        enable = true;
        users = {
          mcamp = {files = ["id_ed25519" "passwords" "kubeconfig"];};
        };
      };

      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/reckless/role-id";
            secret-id = "/var/lib/vault/reckless/secret-id";
          };
        };
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
