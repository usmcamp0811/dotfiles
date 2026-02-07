{ lib, ... }:
with lib; rec {

  lookupServiceEndpoint = { nixosConfigurations, serviceName }:

    let
      # Helper function to construct the URL for a service
      getServiceUrl = host: cfg:
        if cfg.config.fmf.services.${serviceName}.enable or false then
          let port = cfg.config.fmf.services.${serviceName}.port or null;
          in if port != null then {
            url = "http://${host}:${toString port}";
          } else
            null
        else
          null;

      # Collect all URLs for hosts with the service enabled
      serviceUrls = builtins.filter (url: url != null)
        (map (host: getServiceUrl host nixosConfigurations.${host})
          (builtins.attrNames nixosConfigurations));
    in
    serviceUrls;

  getWireGuardPeers = { nixosConfigurations, interfaceName }:

    let
      # Helper function to construct the peer configuration
      getPeerConfig = host: cfg:
        let
          wgConfig =
            cfg.config.networking.wireguard.interfaces.${interfaceName} or { };
          publicKey = wgConfig.publicKey or null;
          presharedKeyFile = wgConfig.presharedKeyFile or null;
          allowedIPs = wgConfig.allowedIPs or [ ];
        in
        if publicKey != null then {
          publicKey = publicKey;
          presharedKeyFile = presharedKeyFile;
          allowedIPs = allowedIPs;
        } else
          null;

      # Collect all peer configurations for hosts with the interface defined
      peerConfigs = builtins.filter (peer: peer != null)
        (map (host: getPeerConfig host nixosConfigurations.${host})
          (builtins.attrNames nixosConfigurations));
    in
    peerConfigs;
}
