{ lib, ... }:
with lib; rec {
  lookupK0sControllers = { nixosConfigurations }:
    let
      getK0sController = host: cfg:
        let
          enabled = cfg.config.campground.services.k0s.enable or false;
          role = cfg.config.campground.services.k0s.role or null;
        in
        if enabled && elem role [ "controller" "controller+worker" ] then {
          name = host;
          value = {
            ip = host;
            port = 6443;
            option = [ "check" ];
          };
        } else
          null;

      controllers = builtins.listToAttrs (builtins.filter (x: x != null)
        (map (host: getK0sController host nixosConfigurations.${host})
          (builtins.attrNames nixosConfigurations)));
    in
    controllers;

}
