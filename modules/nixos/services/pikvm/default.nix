{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.pikvm;

  # Convert settings to YAML format
  settingsFormat = pkgs.formats.yaml { };
  overrideFile = settingsFormat.generate "override.yaml" (recursiveUpdate defaultConfig cfg.settings);

  # Determine the htpasswd file path based on whether passwordFile is set
  htpasswdFile =
    if cfg.passwordFile != null then "/run/kvmd/htpasswd" else "${cfg.package}/etc/kvmd/htpasswd";

  # Extract platform info from hardwareVersion (e.g., "v2-hdmi-rpi4" -> base=v2, video=hdmi, board=rpi4)
  platformParts = lib.splitString "-" cfg.hardwareVersion;
  platformFile = pkgs.writeText "platform" ''
    PIKVM_MODEL=${lib.elemAt platformParts 0}
    PIKVM_VIDEO=${lib.elemAt platformParts 1}
    PIKVM_BOARD=${lib.elemAt platformParts 2}
  '';

  defaultConfig = {
    kvmd.auth.totp.secret.file = "${cfg.package}/etc/kvmd/totp.secret";
    kvmd.auth.internal.file = htpasswdFile;
    kvmd.info.meta = "${cfg.package}/etc/kvmd/meta.yaml";
    kvmd.info.extras = "${cfg.package}/share/kvmd/extras";
    kvmd.info.hw.platform = "${platformFile}";

    # Override Janus paths for NixOS
    janus.cmd = [
      "${pkgs.janus-gateway}/bin/janus"
      "--disable-colors"
      "--plugins-folder=${pkgs.ustreamer}/lib/ustreamer/janus"
      "--configs-folder=${cfg.package}/etc/janus"
      "--interface={src_ip}"
      "{o_stun_server}"
    ];
  };
in
{
  options.fmf.services.pikvm = with types; {
    enable = mkBoolOpt false "Enable PiKVM daemon (KVM over IP)";

    package = mkOption {
      type = types.package;
      default = pkgs.kvmd;
      defaultText = literalExpression "pkgs.kvmd";
      description = "The kvmd package to use.";
    };

    hardwareVersion = mkOption {
      type = types.str;
      default = "v2-hdmi-rpi4";
      description = "The hardware version for udev rules. See https://github.com/pikvm/kvmd/tree/master/configs/os/udev for available options.";
    };

    settings = mkOption {
      type = settingsFormat.type;
      default = { };
      example = literalExpression ''
        {
          kvmd = {
            auth = {
              totp = {
                secret = {
                  file = "/var/lib/kvmd/totp.secret";
                };
              };
            };
            hid = {
              mouse_alt = {
                device = "/dev/kvmd-hid-mouse-alt";
              };
            };
          };
        }
      '';
      description = ''
        Configuration settings for kvmd. These will be converted to YAML
        and placed in the override configuration file.
        See https://docs.pikvm.org for available options.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "admin";
      description = "Username for PiKVM web UI authentication.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the plain text password for the web UI user.
        If set, this password will be hashed and used instead of the default.
        The file should contain only the password with no trailing newline,
        or the newline will be trimmed automatically.
      '';
    };

    nginx = {
      enable = mkBoolOpt true "Enable nginx web server for PiKVM";
      httpPort = mkOption {
        type = types.port;
        default = 80;
        description = "HTTP port for nginx";
      };
      httpsPort = mkOption {
        type = types.port;
        default = 443;
        description = "HTTPS port for nginx";
      };
      httpsEnabled = mkBoolOpt false "Enable HTTPS support";
    };

    openFirewall = mkBoolOpt true "Open firewall ports for kvmd";
  };

  config = mkIf cfg.enable {
    # Create required users and groups
    users.groups = {
      kvmd = { };
      kvmd-ipmi = { };
      kvmd-janus = { };
      kvmd-localhid = { };
      kvmd-media = { };
      kvmd-pst = { };
      kvmd-vnc = { };
      gpio = { };
    };

    users.users = {
      kvmd = {
        description = "KVM over IP daemon user";
        group = "kvmd";
        isSystemUser = true;
        extraGroups = [
          "gpio"
          "video"
          "input"
          "tty"
        ];
      };
      kvmd-ipmi = {
        description = "KVMD IPMI user";
        group = "kvmd-ipmi";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
      kvmd-janus = {
        description = "KVMD Janus user";
        group = "kvmd-janus";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
      kvmd-localhid = {
        description = "KVMD Local HID user";
        group = "kvmd-localhid";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
      kvmd-media = {
        description = "KVMD Media user";
        group = "kvmd-media";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
      kvmd-pst = {
        description = "KVMD Persistent Storage user";
        group = "kvmd-pst";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
      kvmd-vnc = {
        description = "KVMD VNC user";
        group = "kvmd-vnc";
        extraGroups = [ "kvmd" ];
        isSystemUser = true;
      };
    };

    # Raspberry Pi specific configuration (only applies when using Raspberry Pi hardware)
    # Note: The nixos-hardware.nixosModules.raspberry-pi-4 should be imported in the
    # system configuration (default.nix) when using Raspberry Pi hardware
    hardware = mkIf (lib.hasInfix "rpi" cfg.hardwareVersion) {
      raspberry-pi = {
        configtxt.deviceTreeOverlays.pi4 = [ { dwc2.dr_mode = "peripheral"; } ];
        "4" = {
          tc358743.enable = true;
          apply-overlays-dtmerge.enable = true;
        };
        firmware = {
          enable = true;
          uboot.enable = true;
          useGenerationDeviceTree = true;
        };
      };
      i2c.enable = true;
    };

    # Htpasswd generation service (only when passwordFile is set)
    systemd.services.kvmd-htpasswd = mkIf (cfg.passwordFile != null) {
      description = "Generate htpasswd for PiKVM";
      wantedBy = [ "multi-user.target" ];
      before = [ "kvmd.service" ];
      requiredBy = [ "kvmd.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "kvmd";
        RuntimeDirectoryMode = "0755";
      };

      path = [
        pkgs.openssl
        pkgs.coreutils
      ];

      script = ''
        # Read password from file (trim trailing newline if present)
        password=$(tr -d '\n' < ${cfg.passwordFile})

        # Generate 16-byte random salt
        salt=$(openssl rand 16)

        # Generate SSHA512 hash: base64(sha512(password + salt) + salt)
        # This matches the {SSHA512} format used by passlib/LDAP
        hash=$(printf '%s%s' "$password" "$salt" | openssl dgst -sha512 -binary | cat - <(printf '%s' "$salt") | base64 -w0)

        # Write htpasswd file with {SSHA512} prefix
        echo "${cfg.user}:{SSHA512}$hash" > /run/kvmd/htpasswd
        chmod 644 /run/kvmd/htpasswd
        chown kvmd:kvmd /run/kvmd/htpasswd
      '';
    };

    # Main kvmd service
    systemd.services.kvmd = {
      description = "PiKVM daemon";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "kvmd-otg.service"
      ]
      ++ lib.optional (cfg.passwordFile != null) "kvmd-htpasswd.service";

      serviceConfig = {
        Type = "simple";
        User = "kvmd";
        Group = "kvmd";
        RuntimeDirectory = "kvmd kvmd/otg";
        RuntimeDirectoryMode = "0775";
        RuntimeDirectoryPreserve = "yes";
        UMask = "0002";
        ExecStart = "${lib.getExe cfg.package} --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        Restart = "on-failure";
        RestartSec = "3";
      };
    };

    systemd.services.kvmd-ipmi = {
      description = "PiKVM - IPMI to KVMD proxy";
      after = [ "kvmd.service" ];
      serviceConfig = {
        User = "kvmd-ipmi";
        Group = "kvmd-ipmi";
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-ipmi --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        TimeoutStopSec = 3;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-janus = {
      description = "PiKVM - Janus WebRTC Gateway";
      after = [
        "network.target"
        "network-online.target"
        "nss-lookup.target"
        "kvmd.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        User = "kvmd-janus";
        Group = "kvmd-janus";
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        AmbientCapabilities = "CAP_NET_RAW";
        LimitNOFILE = 65536;
        UMask = "0117";
        ExecStart = "${cfg.package}/bin/kvmd-janus --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        TimeoutStopSec = 10;
        KillMode = "mixed";
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-media = {
      description = "PiKVM - Media proxy server";
      after = [ "kvmd.service" ];
      serviceConfig = {
        User = "kvmd-media";
        Group = "kvmd-media";
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        UMask = "0002";
        RuntimeDirectory = "kvmd";
        RuntimeDirectoryMode = "0775";
        RuntimeDirectoryPreserve = "yes";
        ExecStart = "${cfg.package}/bin/kvmd-media --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        TimeoutStopSec = 10;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-oled = {
      description = "PiKVM - A small OLED daemon";
      after = [ "systemd-modules-load.service" ];
      unitConfig = {
        ConditionPathExists = "/dev/i2c-1";
      };
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "3";
        ExecStartPre = "${lib.getBin cfg.package}/bin/kvmd-oled --interval=3 --clear-on-exit --image=@hello.ppm";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-oled --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} ";
        TimeoutStopSec = 3;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-oled-reboot = {
      description = "PiKVM - Display reboot message on the OLED";
      unitConfig = {
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/bash -c 'kill -USR1 `systemctl show -P MainPID kvmd-oled`'";
        ExecStop = "/bin/true";
        RemainAfterExit = true;
      };
      wantedBy = [ "reboot.target" ];
    };

    systemd.services.kvmd-oled-shutdown = {
      description = "PiKVM - Display shutdown message on the OLED";
      unitConfig = {
        Conflicts = "reboot.target";
        Before = [
          "shutdown.target"
          "poweroff.target"
          "halt.target"
        ];
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/bash -c 'kill -USR2 `systemctl show -P MainPID kvmd-oled`'";
        ExecStop = "/bin/true";
        RemainAfterExit = true;
      };
      wantedBy = [ "shutdown.target" ];
    };

    systemd.services.kvmd-otgnet = {
      description = "PiKVM - OTG network service";
      after = [
        "kvmd-otg.service"
        "network-pre.target"
      ];
      wants = [ "network-pre.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-otgnet --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} start";
        ExecStop = "${lib.getBin cfg.package}/bin/kvmd-otgnet --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} stop";
        RemainAfterExit = true;
      };
      # Disabled by default - ECM network function not configured
    };

    systemd.services.kvmd-otg = {
      description = "PiKVM - OTG setup";
      after = [
        "systemd-modules-load.service"
      ];
      before = [ "kvmd.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-otg --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml start";
        ExecStop = "${lib.getBin cfg.package}/bin/kvmd-otg --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml stop";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-pst = {
      description = "PiKVM - The KVMD persistent storage manager";
      after = [ "kvmd.service" ];

      serviceConfig = {
        User = "kvmd-pst";
        Group = "kvmd-pst";
        Type = "simple";
        Restart = "always";
        RestartSec = "3";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-pst --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        TimeoutStopSec = 5;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-tc358743 = mkIf (lib.hasInfix "rpi" cfg.hardwareVersion) {
      description = "PiKVM - EDID loader for TC358743";
      wants = [ "dev-video0.device" ];
      after = [
        "dev-video0.device"
        "systemd-modules-load.service"
      ];
      before = [ "kvmd.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.v4l-utils}/bin/v4l2-ctl --device=/dev/video0 --set-edid=file=${cfg.package}/etc/kvmd/edid/${lib.elemAt (lib.splitString "-" cfg.hardwareVersion) 0}.hex --info-edid";
        ExecStop = "${pkgs.v4l-utils}/bin/v4l2-ctl --device=/dev/video0 --clear-edid";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.kvmd-vnc = {
      description = "PiKVM - VNC to KVMD/Streamer proxy";
      after = [ "kvmd.service" ];
      serviceConfig = {
        User = "kvmd-vnc";
        Group = "kvmd-vnc";
        Type = "simple";
        Restart = "always";
        RestartSec = "3";
        ExecStart = "${lib.getBin cfg.package}/bin/kvmd-vnc --main-config ${cfg.package}/etc/kvmd/main/${cfg.hardwareVersion}.yaml --override-config ${overrideFile} --run";
        TimeoutStopSec = 3;
      };
      wantedBy = [ "multi-user.target" ];
    };

    # Configure sudo permissions for kvmd users
    security.sudo.extraRules = [
      {
        users = [ "kvmd" ];
        commands = [
          {
            command = "${cfg.package}/bin/kvmd-helper-otgmsd-remount *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${cfg.package}/bin/kvmd-helper-pst-remount *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
      {
        users = [ "kvmd-pst" ];
        commands = [
          {
            command = "${cfg.package}/bin/kvmd-helper-pst-remount *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Ensure /dev/gpiochip* nodes are accessible to kvmd (try both possible subsystems)
    services.udev.extraRules = ''
      # GPIO and video device access for kvmd group
      KERNEL=="gpiochip*", SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
      KERNEL=="gpiochip*", SUBSYSTEM=="misc", GROUP="gpio", MODE="0660"
      KERNEL=="vchiq|vcsm|vcio", GROUP="video", MODE="0660"
    ''
    + builtins.readFile "${cfg.package}/etc/os/udev/common.rules"
    + builtins.readFile "${cfg.package}/etc/os/udev/${cfg.hardwareVersion}.rules";

    # Filesystem mounts for PiKVM storage
    fileSystems = {
      "/var/lib/kvmd/msd" = {
        device = "LABEL=PIMSD";
        fsType = "ext4";
        options = [
          "nofail"
          "nodev"
          "nosuid"
          "noexec"
          "ro"
          "errors=remount-ro"
          "X-kvmd.otgmsd-user=kvmd"
        ];
        neededForBoot = false;
      };

      "/var/lib/kvmd/pst" = {
        device = "LABEL=PIPST";
        fsType = "ext4";
        options = [
          "nofail"
          "nodev"
          "nosuid"
          "noexec"
          "X-kvmd.pst-user=kvmd-pst"
        ];
        neededForBoot = false;
      };
    };

    # Nginx configuration
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      appendHttpConfig = ''
        types {
          application/wasm wasm;
        }
      '';

      virtualHosts."pikvm" = {
        listen = [
          { addr = "0.0.0.0"; port = cfg.nginx.httpPort; }
        ] ++ lib.optionals cfg.nginx.httpsEnabled [
          { addr = "0.0.0.0"; port = cfg.nginx.httpsPort; ssl = true; }
        ];

        locations = {
          "/" = {
            root = "${cfg.package}/share/kvmd/web";
            index = "index.html";
            extraConfig = ''
              add_header Cache-Control no-cache;
            '';
          };

          "/api/" = {
            proxyPass = "http://localhost:8080";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_set_header Host $host;
            '';
          };

          "/ws" = {
            proxyPass = "http://localhost:8080";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
            '';
          };
        };
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.nginx.httpPort ]
        ++ lib.optionals cfg.nginx.httpsEnabled [ cfg.nginx.httpsPort ];
    };
  };
}
