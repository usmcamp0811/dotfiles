{ unstable, ... }:

final: prev:

{

  mlflow = unstable.legacyPackages.${prev.system}.mlflow;
}
