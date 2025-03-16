{ lib, pkgs, inputs, ... }:
let

  kubelib = inputs.kube-gen.lib { inherit pkgs; };
  chart = (kubelib.buildHelmChart {
    name = "traefik";
    chart = (inputs.nixhelm.charts { inherit pkgs; }).traefik.traefik;
    namespace = "traefik";
  });
in
chart
