{ lib, ... }:
with lib; rec {
  lookupK0sControllers = { nixosConfigurations }:
    let
      getK0sController = host: cfg:
        let
          enabled = cfg.config.campground.services.k0s.enable or false;
          role = cfg.config.campground.services.k0s.role or null;
          apiPort = cfg.config.campground.services.k0s.apiPort or 6443;
        in
        if enabled && elem role [ "controller" "controller+worker" ] then {
          inherit port;
        } else
          null;

      controllers = builtins.listToAttrs (builtins.filter (x: x != null) (map
        (host:
          let entry = getK0sController host nixosConfigurations.${host};
          in if entry != null then {
            name = host;
            value = entry;
          } else
            null)
        (builtins.attrNames nixosConfigurations)));
    in
    controllers;
}
