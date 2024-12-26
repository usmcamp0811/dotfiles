{ lib, inputs, ... }:
with lib; rec {

  lookupServiceEndpoint = { nixosConfigurations, serviceName }:

    let
      # Helper function to construct the URL for a service
      getServiceUrl = host: cfg:
        if cfg.config.campground.services.${serviceName}.enable or false then
          let port = cfg.config.campground.services.${serviceName}.port or null;
          in if port != null then "http://${host}:${toString port}" else null
        else
          null;

      # Collect all URLs for hosts with the service enabled
      serviceUrls = builtins.filter (url: url != null)
        (map (host: getServiceUrl host nixosConfigurations.${host})
          (builtins.attrNames nixosConfigurations));
    in
    serviceUrls;

}
