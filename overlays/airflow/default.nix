{ campground-packages, ... }:
final: prev: {
  apache-airflow = campground-packages.packages.${prev.system}.airflow;
}
