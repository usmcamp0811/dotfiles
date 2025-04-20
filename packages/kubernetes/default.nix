{ lib
, pkgs
, inputs
, ...
}:
let
  nixidyEnvs = pkgs.nixidy-lib.mkEnvs {
    inherit pkgs;

    envs = {
      # Currently we only have the one dev env.
      dev.modules = [ ./env/dev.nix ];
    };
  };
  kubelib = inputs.kube-gen.lib { inherit pkgs; };
  chart = kubelib.buildHelmChart {
    name = "traefik";
    chart = (inputs.nixhelm.charts { inherit pkgs; }).traefik.traefik;
    namespace = "traefik";
  };
in
chart
