{ campground-jupyterlab, ... }:
final: prev: {
  jupyterlab = campground-jupyterlab.packages.${prev.system}.default;
}
