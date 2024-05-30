{ channels, unstable, nixpkgs, ... }:
final: prev: {
  # inherit (channels.unstable) python311Packages;
  python3-11 = unstable.legacyPackages.${prev.system}.python311;
  mlflow-unstable =
    unstable.legacyPackages.${prev.system}.python311Packages.mlflow;
  boto3-unstable =
    unstable.legacyPackages.${prev.system}.python311Packages.boto3;
  psycopg2-unstable =
    unstable.legacyPackages.${prev.system}.python311Packages.psycopg2;
  mysqlclient-unstable =
    unstable.legacyPackages.${prev.system}.python311Packages.mysqlclient;
  gunicorn-unstable =
    unstable.legacyPackages.${prev.system}.python311Packages.gunicorn;
  poetry = nixpkgs.legacyPackages.${prev.system}.poetry;
}
