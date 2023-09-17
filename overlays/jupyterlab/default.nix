{ campground-jupyterlab, ... }:

final: prev:

{
  jupyterlab = campground-jupyterlab.packages.${prev.system}.default;
  # jupyterlab = jupyenv.packages.${prev.system}.jupyterlab;
}

