# Development tools and language-specific packages
{
  channels,
  unstable,
  nixpkgs,
  llm-agents,
  nixery-flake,
  ...
}: final: prev: {
  # Python & ML development
  python3-11 = unstable.legacyPackages.${prev.system}.python311;
  python311Packages-unstable = unstable.legacyPackages.${prev.system}.python311Packages.mlflow;
  mlflow-unstable = unstable.legacyPackages.${prev.system}.python311Packages.mlflow;
  mlflow-server = channels.unstable.mlflow-server;
  boto3-unstable = unstable.legacyPackages.${prev.system}.python311Packages.boto3;
  psycopg2-unstable = unstable.legacyPackages.${prev.system}.python311Packages.psycopg2;
  mysqlclient-unstable = unstable.legacyPackages.${prev.system}.python311Packages.mysqlclient;
  gunicorn-unstable = unstable.legacyPackages.${prev.system}.python311Packages.gunicorn;
  poetry = nixpkgs.legacyPackages.${prev.system}.poetry;
  backlog-md = channels.backlog.packages.${prev.system}.backlog-md;

  # LLM Things
  llm-agents = llm-agents.packages.${prev.system};

  # Python package building
  nix-python = channels.nixpkgs-python.packages.${prev.system};
  arrow-cpp_11 = channels.pyarrow.packages.${prev.system}.arrow-cpp;

  # Nixery for dynamic container images
  nixery-pkgs = import nixery-flake.outPath {
    pkgs = import nixpkgs {system = "${prev.system}";};
  };

  # Unstable access point for ad-hoc packages
  nix-unstable = unstable.legacyPackages.${prev.system};
}
