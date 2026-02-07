{ ... }: {
  campnet.peers = [
    {
      name = "daly";
      publicKey = "qUnW//Iq8eq2D5dKMfsIa0zCewUSOSVaLtpO7AxWXAE=";
      allowedIPs = [ "10.100.0.10/32" ];
    }
    {
      name = "butler";
      publicKey = "Thdtm9iUmcZFgFMiJUm0T0EaBe/gvfmcBHrSi5Gvfm8=";
      presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
      allowedIPs = [ "10.100.0.2/32" ];
    }
    {
      name = "phone";
      publicKey = "cq5+lO9tjEom1pUuXtb9rfAfSN6DZxDZkKWdVQ6Cokw=";
      presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
      allowedIPs = [ "10.100.0.3/32" ];
    }
  ];
}
