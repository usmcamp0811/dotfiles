# Development tools and language-specific packages
{ channels, unstable, nixpkgs, llm-agents, nixery-flake, ... }:
final: prev: let
  system = prev.stdenv.hostPlatform.system;
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
  llm-agents = llm-agents.packages.${system};

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
