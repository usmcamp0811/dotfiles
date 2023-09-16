{ jupyenv, ... }:

final: prev:

{
  jupyenv = jupyenv.packages.${prev.system}.default;
  jupyterlab = jupyenv.packages.${prev.system}.jupyterlab;
}

