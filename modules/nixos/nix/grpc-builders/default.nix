{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.nix.grpc-builders;
  hasBuilders = cfg.builders != { };

  builderModule = types.submodule {
    options = {
      host = mkOption {
        type = types.str;
        description = "Hostname or address of the gRPC Nix builder or farm.";
      };

      port = mkOpt types.port 443 "TCP port used by the gRPC Nix endpoint.";
      systems = mkOpt (types.listOf types.str) [ "x86_64-linux" ] "Systems this endpoint can build.";
      max-jobs = mkOpt types.int 1 "Maximum concurrent jobs submitted to this endpoint.";
      speed-factor = mkOpt types.int 1 "Relative speed of this builder.";
      supported-features =
        mkOpt (types.listOf types.str) [ ]
          "System features supported by this builder or farm.";
      mandatory-features =
        mkOpt (types.listOf types.str) [ ]
          "Features required for jobs assigned to this builder.";
      ca-cert =
        mkOpt (types.nullOr types.str) null
          "Runtime path to the CA certificate used to verify the gRPC server.";
      client-cert =
        mkOpt (types.nullOr types.str) null
          "Runtime path to the client certificate used for mTLS.";
      client-key =
        mkOpt (types.nullOr types.str) null
          "Runtime path to the client private key used for mTLS.";
      token-file = mkOpt (types.nullOr types.str) null "Runtime path to an OIDC bearer token.";
      insecure = mkBoolOpt false "Use plaintext gRPC. Intended only for trusted test networks.";
      connect-timeout = mkOpt types.ints.positive 30 "Initial gRPC connection timeout in seconds.";
    };
  };

  queryFor =
    builder: system:
    concatStringsSep "&" (
      [
        "system=${system}"
        "connect-timeout=${toString builder.connect-timeout}"
      ]
      ++ optional builder.insecure "insecure=1"
      ++ optional (builder.ca-cert != null) "ca-cert=${builder.ca-cert}"
      ++ optional (builder.client-cert != null) "client-cert=${builder.client-cert}"
      ++ optional (builder.client-key != null) "client-key=${builder.client-key}"
      ++ optional (builder.token-file != null) "token-file=${builder.token-file}"
    );

  uriFor =
    builder: system: "grpc://${builder.host}:${toString builder.port}?${queryFor builder system}";

  machinesFor =
    builder:
    map (system: {
      hostName = uriFor builder system;
      protocol = null;
      inherit system;
      maxJobs = builder.max-jobs;
      speedFactor = builder.speed-factor;
      supportedFeatures = builder.supported-features;
      mandatoryFeatures = builder.mandatory-features;
    }) builder.systems;

  buildMachines = concatMap machinesFor (attrValues cfg.builders);
  daemonEgressPorts = unique (map (builder: builder.port) (attrValues cfg.builders));
in
{
  options.fmf.nix.grpc-builders = {
    enable = mkBoolOpt false "Whether to configure remote Nix builders over gRPC.";
    builders =
      mkOpt (types.attrsOf builderModule) { }
        "gRPC builders or build farms keyed by a descriptive name.";
    use-substitutes = mkBoolOpt true "Whether remote builders may use configured substituters.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasBuilders;
        message = "fmf.nix.grpc-builders requires at least one builder";
      }
    ]
    ++ concatMap (builder: [
      {
        assertion = (builder.client-cert == null) == (builder.client-key == null);
        message = "fmf.nix.grpc-builders client-cert and client-key must be configured together";
      }
      {
        assertion =
          !builder.insecure
          || (
            builder.ca-cert == null
            && builder.client-cert == null
            && builder.client-key == null
            && builder.token-file == null
          );
        message = "fmf.nix.grpc-builders insecure mode cannot be combined with TLS or token authentication";
      }
    ]) (attrValues cfg.builders);

    programs.nix-grpc-store = {
      enable = true;
      inherit daemonEgressPorts;
    };

    nix = {
      distributedBuilds = true;
      inherit buildMachines;
      settings.builders-use-substitutes = cfg.use-substitutes;
    };
  };
}
