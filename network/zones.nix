# The fleet's network zones, shared by every host (fmf.network.zones). Host interfaces refer to a
# zone by its id. Mirrors blue-ridge's router zones (fmf.router.zones in
# systems/x86_64-linux/blue-ridge/default.nix); hostDomain is the domain under which host names resolve.
# Spec: docs/HOST-MODEL.md.
{...}: {
  fmf.network.zones = {
    lan = {
      description = "Main LAN network for trusted devices and VMs";
      dhcpRange = {
        start = "192.169.1.50";
        end = "192.169.1.200";
      };
      dns = ["192.169.1.2"];
      gateway = "192.169.1.1";
      hostDomain = "lan-hosts.aicampground.com";
      subnet = "192.169.1.0/24";
    };
    wifi = {
      description = "WiFi network for wireless devices";
      dhcpRange = {
        start = "192.169.10.50";
        end = "192.169.10.200";
      };
      dns = ["192.169.1.2"];
      gateway = "192.169.10.1";
      hostDomain = "wifi-hosts.aicampground.com";
      subnet = "192.169.10.0/24";
      vlanId = 10;
    };
    iot = {
      description = "IoT network for smart home devices";
      dhcpRange = {
        start = "192.169.20.50";
        end = "192.169.20.200";
      };
      dns = ["192.169.1.2"];
      gateway = "192.169.20.1";
      hostDomain = "iot-hosts.aicampground.com";
      subnet = "192.169.20.0/24";
      vlanId = 20;
    };
    guest = {
      description = "Guest network for visitors";
      dhcpRange = {
        start = "192.169.30.50";
        end = "192.169.30.200";
      };
      dns = ["192.169.1.2"];
      gateway = "192.169.30.1";
      subnet = "192.169.30.0/24";
      vlanId = 30;
    };
  };
}
