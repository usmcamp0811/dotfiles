{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.nix.remote-builders;
  hasBuilders = cfg.builders != { };

  builderModule = types.submodule {
    options = {
      host = mkOption {
        type = types.str;
        description = "Hostname or address of the remote builder.";
      };
      systems = mkOpt (types.listOf types.str) [ "x86_64-linux" ] "Systems the builder can build.";
      ssh-user = mkOpt types.str "nix-ssh" "SSH user used for remote builds.";
      ssh-key =
        mkOpt (types.nullOr types.str) null
          "Daemon-readable SSH private key used for remote builds.";
      protocol = mkOpt (types.enum [
        "ssh"
        "ssh-ng"
      ]) "ssh-ng" "Nix SSH protocol to use.";
      max-jobs = mkOpt types.int 1 "Maximum concurrent jobs assigned to this builder.";
      speed-factor = mkOpt types.int 1 "Relative speed of this builder.";
      supported-features =
        mkOpt (types.listOf types.str) [ ]
          "Optional system features supported by this builder.";
      mandatory-features =
        mkOpt (types.listOf types.str) [ ]
          "Features required for jobs assigned to this builder.";
      public-host-key = mkOpt (types.nullOr types.str) null "Base64-encoded SSH host public key.";
    };
  };

  machineFor = builder: {
    hostName = builder.host;
    inherit (builder) systems protocol;
    sshUser = builder.ssh-user;
    sshKey = if builder.ssh-key != null then builder.ssh-key else cfg.ssh-key;
    maxJobs = builder.max-jobs;
    speedFactor = builder.speed-factor;
    supportedFeatures = builder.supported-features;
    mandatoryFeatures = builder.mandatory-features;
    publicHostKey = builder.public-host-key;
  };
in
{
  options.fmf.nix.remote-builders = {
    enable = mkBoolOpt false "Whether to configure remote Nix builders.";
    serve = mkBoolOpt false "Whether to accept builds through the restricted nix-ssh account.";
    authorized-keys =
      mkOpt (types.listOf types.str) config.fmf.services.openssh.authorizedKeys
        "SSH public keys allowed to submit builds.";
    builders = mkOpt (types.attrsOf builderModule) { } "Remote builders keyed by a descriptive name.";
    ssh-key =
      mkOpt (types.nullOr types.str) null
        "Default daemon-readable SSH private key for builders.";
    use-substitutes = mkBoolOpt true "Whether remote builders may use configured substituters.";
    connect-timeout = mkOpt types.ints.positive 3 "SSH connection timeout in seconds.";
    host-key-checking = mkOpt (types.enum [
      "strict"
      "accept-new"
      "insecure"
    ]) "accept-new" "SSH host-key policy for builders without public-host-key.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.serve || hasBuilders;
        message = "fmf.nix.remote-builders must either serve builds or configure builders";
      }
    ];

    nix = {
      sshServe = mkIf cfg.serve {
        enable = true;
        protocol = "ssh-ng";
        trusted = true;
        keys = cfg.authorized-keys;
      };
      distributedBuilds = hasBuilders;
      buildMachines = mapAttrsToList (_: machineFor) cfg.builders;
      settings = mkIf hasBuilders {
        builders-use-substitutes = cfg.use-substitutes;
        connect-timeout = cfg.connect-timeout;
      };
    };

    programs.ssh.extraConfig = mkIf hasBuilders (
      concatMapStringsSep "\n" (builder: ''
        Host ${builder.host}
          BatchMode yes
          ConnectTimeout ${toString cfg.connect-timeout}
          ConnectionAttempts 1
          StrictHostKeyChecking ${
            {
              strict = "yes";
              accept-new = "accept-new";
              insecure = "no";
            }
            .${cfg.host-key-checking}
          }
          ${optionalString (cfg.host-key-checking == "insecure") "UserKnownHostsFile /dev/null"}
      '') (attrValues cfg.builders)
    );
  };
}
