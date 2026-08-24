# Development tools and language-specific packages
{ channels, unstable, nixpkgs, llm-agents, nixery-flake, ... }:
final: prev: let
  system = prev.stdenv.hostPlatform.system;
  upstreamLlmAgents = llm-agents.packages.${system};
  sharedLlmAgents =
    (llm-agents.overlays.shared-nixpkgs final prev).llm-agents;
in {
  # Python & ML development
  python3-11 = unstable.legacyPackages.${system}.python311;
  python311Packages-unstable =
    unstable.legacyPackages.${system}.python311Packages.mlflow;
  mlflow-unstable =
    unstable.legacyPackages.${system}.python311Packages.mlflow;
  mlflow-server = channels.unstable.mlflow-server;
  boto3-unstable =
    unstable.legacyPackages.${system}.python311Packages.boto3;
  psycopg2-unstable =
    unstable.legacyPackages.${system}.python311Packages.psycopg2;
  mysqlclient-unstable =
    unstable.legacyPackages.${system}.python311Packages.mysqlclient;
  gunicorn-unstable =
    unstable.legacyPackages.${system}.python311Packages.gunicorn;
  poetry = nixpkgs.legacyPackages.${system}.poetry;

  # LLM Things
  llm-agents = upstreamLlmAgents // {
    # Build mistral-vibe against this flake's Python package set so local
    # compatibility fixes apply to its dependencies.
    mistral-vibe = sharedLlmAgents.mistral-vibe;
  };

  # Python package building
  nix-python = channels.nixpkgs-python.packages.${system};
  arrow-cpp_11 = channels.pyarrow.packages.${system}.arrow-cpp;

  # Nixery for dynamic container images
  nixery-pkgs = import nixery-flake.outPath {
    pkgs = import nixpkgs { inherit system; };
  };

  # Unstable access point for ad-hoc packages
  nix-unstable = unstable.legacyPackages.${system};
}
