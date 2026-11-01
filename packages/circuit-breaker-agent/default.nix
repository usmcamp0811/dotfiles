{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}: let
  version = "0.4.6";
in
  buildGoModule {
    pname = "circuit-breaker-agent";
    inherit version;

    # Pinned to the exact upstream commit of v${version} (not a moving tag).
    src = fetchFromGitHub {
      owner = "BlkLeg";
      repo = "CircuitBreaker";
      rev = "fc44f2ec1ed930b0b8ca4b54979833f31ba1c00f";
      hash = "sha256-T+m6jKPxCov2ovimiK8Z38zSMBLbDTumkUH+2XGWjQY=";
    };
    modRoot = "apps/agent";
    subPackages = ["cmd/cb-agent"];
    vendorHash = "sha256-2ffvqZIhJLp0ABomnQMeDt2cqBRhR8GwCxqPj4WwDpw=";

    ldflags = [
      "-s"
      "-w"
      "-X main.AgentVersion=${version}"
    ];

    # Two deliberate, minimal deviations from the upstream installer layout, both
    # because this binary is managed by Nix:
    #  1. the one-time enrollment token is read from a tmpfs path the systemd unit
    #     populates from a protected credential (upstream hard-codes /etc/...);
    #  2. server-pushed self-update instructions are refused, so the agent can never
    #     replace itself with a binary that bypasses the Nix store. Upgrade by
    #     changing this package.
    postPatch = ''
           substituteInPlace apps/agent/internal/enroll/enroll.go \
             --replace-fail 'var enrollTokenPath = "/etc/circuit-breaker/enroll-token"' \
                            'var enrollTokenPath = "/run/cb-agent/enroll-token"'
           substituteInPlace apps/agent/cmd/cb-agent/updateworker.go \
             --replace-fail 'func (w *updateWorker) enqueue(payload json.RawMessage) error {' \
                            'func (w *updateWorker) enqueue(payload json.RawMessage) error {
      if payload != nil {
      	return errors.New("self-update is disabled: this agent is managed by Nix (change the package to upgrade)")
      }'
    '';

    # The upstream test-suite exercises the self-updater we deliberately disable;
    # the patches above fail the build loudly if upstream code moves.
    doCheck = false;

    meta = {
      description = "Circuit Breaker monitoring/probe agent (outbound-only), pinned and Nix-managed";
      homepage = "https://github.com/BlkLeg/CircuitBreaker";
      license = lib.licenses.mit;
      mainProgram = "cb-agent";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
