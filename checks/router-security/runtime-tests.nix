# Runtime security tests - these scripts are installed on the router
# and can be run to test actual firewall behavior, not just configuration
{ pkgs, lib, routerCfg }:

{
  # Internal tests (run on router itself)
  internalTests = pkgs.writeScriptBin "router-pentest-internal" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    PASSED=0
    FAILED=0

    pass() { echo -e "''${GREEN}[PASS]''${NC} $1"; ((PASSED++)); }
    fail() { echo -e "''${RED}[FAIL]''${NC} $1"; ((FAILED++)); }
    info() { echo "[INFO] $1"; }
    section() { echo ""; echo "===========$1==========="; }

    section "Internal Router Security Tests"
    info "Run from: router itself"
    echo ""

    # Test firewall is active
    section "Firewall Status"
    if ${pkgs.systemd}/bin/systemctl is-active --quiet nftables.service; then
      pass "nftables is active"
    else
      fail "nftables is NOT active"
    fi

    # Test default drop policy
    section "Firewall Policy"
    if ${pkgs.nftables}/bin/nft list ruleset | ${pkgs.gnugrep}/bin/grep -q "policy drop"; then
      pass "Found DROP policy in ruleset"
    else
      fail "No DROP policy found"
    fi

    # Test SSH only listens on LAN
    section "SSH Listening Interfaces"
    SSH_LISTENERS=$(${pkgs.nettools}/bin/netstat -tlnp 2>/dev/null | ${pkgs.gnugrep}/bin/grep ":22 " || true)
    if echo "$SSH_LISTENERS" | ${pkgs.gnugrep}/bin/grep -q "${routerCfg.lan.gateway}:22"; then
      pass "SSH listening on LAN interface (${routerCfg.lan.gateway}:22)"
    else
      fail "SSH not listening on expected LAN interface"
    fi

    if echo "$SSH_LISTENERS" | ${pkgs.gnugrep}/bin/grep -qE "0\.0\.0\.0:22|:::22"; then
      fail "SSH listening on ALL interfaces (security risk)"
    else
      pass "SSH not listening on all interfaces"
    fi

    # Test IP forwarding
    section "Routing Configuration"
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
      pass "IP forwarding enabled"
    else
      fail "IP forwarding disabled"
    fi

    # Test RP filter (anti-spoofing)
    section "Anti-Spoofing"
    RP=$(cat /proc/sys/net/ipv4/conf/all/rp_filter)
    if [ "$RP" -ge 1 ]; then
      pass "Reverse path filtering enabled ($RP)"
    else
      fail "Reverse path filtering disabled"
    fi

    # Test SYN cookies
    section "DDoS Protection"
    if [ "$(cat /proc/sys/net/ipv4/tcp_syncookies)" = "1" ]; then
      pass "SYN cookies enabled"
    else
      fail "SYN cookies disabled"
    fi

    # Test zone interfaces exist
    ${lib.optionalString (routerCfg.zones.enable or false) ''
      section "Network Zones"
      ${lib.concatMapStrings (zoneName: let
        zone = routerCfg.zones.zones.${zoneName};
      in ''
        if ${pkgs.iproute2}/bin/ip addr show ${zone.interface} &>/dev/null; then
          pass "Zone '${zoneName}' interface ${zone.interface} exists"
        else
          fail "Zone '${zoneName}' interface ${zone.interface} missing"
        fi
      '') (lib.attrNames routerCfg.zones.zones)}
    ''}

    # Summary
    echo ""
    echo "==========Summary=========="
    echo -e "''${GREEN}Passed: $PASSED''${NC}"
    echo -e "''${RED}Failed: $FAILED''${NC}"
    [ $FAILED -eq 0 ] && echo -e "''${GREEN}ALL TESTS PASSED''${NC}" || echo -e "''${RED}TESTS FAILED''${NC}"
    exit $FAILED
  '';

  # External tests (run from outside the network)
  externalTests = pkgs.writeScriptBin "router-pentest-external" ''
    #!${pkgs.bash}/bin/bash
    # Run this from OUTSIDE your network to test WAN exposure
    # Usage: router-pentest-external <WAN_IP>

    if [ $# -lt 1 ]; then
      echo "Usage: $0 <WAN_IP>"
      echo "Get your WAN IP from: curl ifconfig.me"
      exit 1
    fi

    WAN="$1"
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'

    PASSED=0
    FAILED=0

    pass() { echo -e "''${GREEN}[PASS]''${NC} $1"; ((PASSED++)); }
    fail() { echo -e "''${RED}[FAIL]''${NC} $1"; ((FAILED++)); }
    info() { echo "[INFO] $1"; }
    section() { echo ""; echo "===========$1==========="; }

    section "External WAN Penetration Test"
    info "Target: $WAN"
    info "Testing from: $(${pkgs.curl}/bin/curl -s ifconfig.me 2>/dev/null || echo 'unknown')"
    echo ""

    # SSH should be closed
    section "SSH Exposure"
    if ${pkgs.nmap}/bin/nmap -p 22 -Pn --max-retries 1 --host-timeout 5s "$WAN" | ${pkgs.gnugrep}/bin/grep -q "22/tcp open"; then
      fail "SSH (22) is OPEN on WAN - CRITICAL VULNERABILITY"
    else
      pass "SSH (22) is closed on WAN"
    fi

    # Scan expected open ports
    section "Expected Open Ports"
    ${lib.concatMapStrings (fwd: ''
      if ${pkgs.nmap}/bin/nmap -p ${toString fwd.port} -Pn --max-retries 1 --host-timeout 5s "$WAN" | ${pkgs.gnugrep}/bin/grep -q "${toString fwd.port}/tcp open"; then
        pass "Port ${toString fwd.port} is open (expected: ${fwd.description})"
      else
        info "Port ${toString fwd.port} appears closed (may be filtered)"
      fi
    '') routerCfg.portForwards}

    # Scan for dangerous services
    section "Vulnerable Services Scan"
    DANGEROUS="21,23,25,135,139,445,3306,3389,5432,5900"
    info "Scanning dangerous ports: $DANGEROUS"
    FOUND=$(${pkgs.nmap}/bin/nmap -p "$DANGEROUS" -Pn --max-retries 1 --host-timeout 10s "$WAN" 2>/dev/null | ${pkgs.gnugrep}/bin/grep "open" || true)
    if [ -z "$FOUND" ]; then
      pass "No dangerous services (FTP,Telnet,SMB,MySQL,RDP,VNC) exposed"
    else
      fail "DANGEROUS SERVICES FOUND:\n$FOUND"
    fi

    # Quick UDP scan
    section "UDP Exposure"
    info "Scanning common UDP ports..."
    UDP=$(${pkgs.nmap}/bin/nmap -sU -p 53,123,161,500 -Pn --max-retries 1 --host-timeout 10s "$WAN" 2>/dev/null | ${pkgs.gnugrep}/bin/grep "open" || true)
    if [ -z "$UDP" ]; then
      pass "No unexpected UDP services exposed"
    else
      fail "UDP services found:\n$UDP"
    fi

    # Summary
    echo ""
    echo "==========Summary=========="
    echo -e "''${GREEN}Passed: $PASSED''${NC}"
    echo -e "''${RED}Failed: $FAILED''${NC}"
    [ $FAILED -eq 0 ] && echo -e "''${GREEN}NO VULNERABILITIES''${NC}" || echo -e "''${RED}VULNERABILITIES FOUND''${NC}"
    exit $FAILED
  '';

  # Zone isolation test
  zoneTests = pkgs.writeScriptBin "router-pentest-zones" ''
    #!${pkgs.bash}/bin/bash
    # Test network zone isolation
    # This requires you to have devices in different zones

    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    section() { echo ""; echo "===========$1==========="; }
    info() { echo "[INFO] $1"; }

    section "Zone Isolation Test"
    echo ""
    echo "This test requires manual verification:"
    echo ""

    ${lib.optionalString (routerCfg.zones.enable or false) ''
      ${lib.concatMapStrings (zoneName: let
        zone = routerCfg.zones.zones.${zoneName};
      in ''
        echo -e "''${YELLOW}Zone: ${zoneName}''${NC}"
        echo "  Subnet: ${zone.subnet}"
        echo "  Gateway: ${zone.gateway}"
        echo "  Isolation: ${zone.isolation}"
        echo ""

        ${if zone.isolation == "full" then ''
          echo "  ✓ Should NOT be able to ping other zones (except via explicit routes)"
          echo "  ✓ Should be able to access internet: ${if zone.allowInternet then "YES" else "NO"}"
        '' else if zone.isolation == "partial" then ''
          echo "  ✓ Should be able to ping LAN zone only"
          echo "  ✓ Should be able to access internet: ${if zone.allowInternet then "YES" else "NO"}"
        '' else ''
          echo "  ✓ Should be able to ping all zones"
        ''}
        echo ""
      '') (lib.attrNames routerCfg.zones.zones)}

      echo "Manual test steps:"
      echo "1. Connect a device to each zone"
      echo "2. Try to ping devices in other zones"
      echo "3. Verify isolation matches the policy above"
      echo ""
      echo "Example test commands:"
      echo "  ping ${routerCfg.lan.gateway}    # Should always work"
      ${lib.concatMapStrings (zoneName: let
        zone = routerCfg.zones.zones.${zoneName};
      in ''
        echo "  ping ${zone.gateway}       # From ${zoneName} zone"
      '') (lib.attrNames routerCfg.zones.zones)}
    ''}
  '';
}
