{ lib, ... }:
with lib; rec {
  lookupK0sControllers = { nixosConfigurations, port ? 6443 }:
    let
      getK0sController = host: cfg:
        let
          enabled = cfg.config.campground.suites.kubernetes.enable or false;
          role = cfg.config.campground.suites.kubernetes.role or null;
        in
        if enabled && elem role [ "controller" "controller+worker" ] then {
          name = host;
          value = {
            ip = cfg.config.networking.hostName or host;
            inherit port;
            options = [ "check" "check-ssl" "verify" "none" ];
          };
        } else
          null;

      controllers = builtins.listToAttrs (builtins.filter (x: x != null)
        (map (host: getK0sController host nixosConfigurations.${host})
          (builtins.attrNames nixosConfigurations)));
    in
    controllers;

}
