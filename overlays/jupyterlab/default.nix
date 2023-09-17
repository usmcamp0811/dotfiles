{ campground-jupyterlab, ... }:

final: prev:

{
  jupyter-lab = campground-jupyterlab.packages.${prev.system}.default;
  # jupyterlab = jupyenv.packages.${prev.system}.jupyterlab;
}

