{
  pkgs,
  inputs,
  lib,
  system,
  ...
}:
# Simplified network isolation test
# Tests zone isolation using test framework's virtual networks

pkgs.testers.nixosTest {
  name = "router-network-isolation-test";

  nodes = {
    # Router with 3 interfaces (simulating LAN, WiFi, IoT zones)
    router = {
      config,
      pkgs,
      lib,
      ...
    }: {
      virtualisation.vlans = [ 1 2 3 ]; # LAN, WiFi, IoT

      # Manual network config for test
      networking = {
        useNetworkd = false;
        useDHCP = false;
        firewall.enable = false; # We'll use nftables directly

        # Configure interfaces manually
        interfaces = {
          eth1.ipv4.addresses = [{ address = "192.168.1.1"; prefixLength = 24; }];
          eth2.ipv4.addresses = [{ address = "192.168.10.1"; prefixLength = 24; }];
          eth3.ipv4.addresses = [{ address = "192.168.20.1"; prefixLength = 24; }];
        };
      };

      # Enable nftables
      networking.nftables.enable = true;

      # Add nftables rules for zone isolation
      networking.nftables.ruleset = lib.mkAfter ''
        table ip filter {
          chain forward {
            type filter hook forward priority 0; policy drop;

            # Allow established connections
            ct state { established, related } accept

            # LAN (eth1) can access everything
            iifname "eth1" accept

            # WiFi (eth2) can only access LAN
            iifname "eth2" oifname "eth1" accept

            # IoT (eth3) is fully isolated (can't reach LAN or WiFi)
            # Implicitly blocked by default drop policy
          }
        }

        # NAT for internet access
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "eth0" masquerade
          }
        }
      '';

      services.timesyncd.enable = lib.mkForce false;
      environment.systemPackages = [ pkgs.iputils ];

      # Enable IP forwarding
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    };

    # Client in LAN zone
    lan-client = {
      virtualisation.vlans = [ 1 ];
      networking = {
        useDHCP = false;
        interfaces.eth1.ipv4.addresses = [{ address = "192.168.1.10"; prefixLength = 24; }];
        defaultGateway = "192.168.1.1";
      };
      environment.systemPackages = [ pkgs.iputils ];
    };

    # Client in WiFi zone
    wifi-client = {
      virtualisation.vlans = [ 2 ];
      networking = {
        useDHCP = false;
        interfaces.eth1.ipv4.addresses = [{ address = "192.168.10.10"; prefixLength = 24; }];
        defaultGateway = "192.168.10.1";
      };
      environment.systemPackages = [ pkgs.iputils ];
    };

    # Client in IoT zone
    iot-client = {
      virtualisation.vlans = [ 3 ];
      networking = {
        useDHCP = false;
        interfaces.eth1.ipv4.addresses = [{ address = "192.168.20.10"; prefixLength = 24; }];
        defaultGateway = "192.168.20.1";
      };
      environment.systemPackages = [ pkgs.iputils ];
    };
  };

  testScript = ''
    start_all()

    # Wait for all VMs
    router.wait_for_unit("multi-user.target")
    lan_client.wait_for_unit("multi-user.target")
    wifi_client.wait_for_unit("multi-user.target")
    iot_client.wait_for_unit("multi-user.target")

    # Wait for network interfaces to be configured
    router.wait_until_succeeds("ip addr show eth1 | grep 192.168.1.1")
    router.wait_until_succeeds("ip addr show eth2 | grep 192.168.10.1")
    router.wait_until_succeeds("ip addr show eth3 | grep 192.168.20.1")

    print("="*60)
    print("ROUTER NETWORK ISOLATION TEST")
    print("="*60)

    # Test 1: LAN -> Router
    with subtest("LAN can reach router"):
        lan_client.succeed("ping -c 1 192.168.1.1")
        print("[PASS] LAN can ping router")

    # Test 2: WiFi -> Router
    with subtest("WiFi can reach router"):
        wifi_client.succeed("ping -c 1 192.168.10.1")
        print("[PASS] WiFi can ping router")

    # Test 3: IoT -> Router
    with subtest("IoT can reach router"):
        iot_client.succeed("ping -c 1 192.168.20.1")
        print("[PASS] IoT can ping router")

    # Test 4: WiFi -> LAN (should work - partial isolation)
    with subtest("WiFi can reach LAN"):
        wifi_client.succeed("ping -c 1 192.168.1.10")
        print("[PASS] WiFi can reach LAN (partial isolation)")

    # Test 5: IoT -> LAN (should FAIL - full isolation)
    with subtest("IoT BLOCKED from LAN"):
        iot_client.fail("ping -c 1 -W 2 192.168.1.10")
        print("[PASS] IoT cannot reach LAN (full isolation working!)")

    # Test 6: IoT -> WiFi (should FAIL - full isolation)
    with subtest("IoT BLOCKED from WiFi"):
        iot_client.fail("ping -c 1 -W 2 192.168.10.10")
        print("[PASS] IoT cannot reach WiFi (full isolation working!)")

    # Test 7: LAN -> WiFi (should work - LAN has full access)
    with subtest("LAN can reach WiFi"):
        lan_client.succeed("ping -c 1 192.168.10.10")
        print("[PASS] LAN can reach WiFi")

    # Test 8: LAN -> IoT (should work - LAN has full access)
    with subtest("LAN can reach IoT"):
        lan_client.succeed("ping -c 1 192.168.20.10")
        print("[PASS] LAN can reach IoT")

    # Test 9: Firewall is running
    with subtest("Firewall active"):
        router.succeed("systemctl is-active nftables.service")
        print("[PASS] Firewall is active")

    # Test 10: Check IP forwarding
    with subtest("IP forwarding enabled"):
        output = router.succeed("cat /proc/sys/net/ipv4/ip_forward").strip()
        assert output == "1", "IP forwarding disabled"
        print("[PASS] IP forwarding enabled")

    print("\n" + "="*60)
    print("ALL NETWORK ISOLATION TESTS PASSED!")
    print("="*60)
    print("Summary:")
    print("  ✓ LAN has full access to all zones")
    print("  ✓ WiFi can access LAN (partial isolation)")
    print("  ✓ IoT is fully isolated (cannot reach LAN or WiFi)")
    print("  ✓ Firewall properly enforcing zone policies")
  '';
}
