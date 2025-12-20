{ pkgs, lib, system ? "x86_64-linux" }:

# Router security penetration test check
# This creates a derivation that runs security tests against the router configuration
# Run with: nix build .#checks.x86_64-linux.router-security

let
  # We need to get the actual config from the built system
  # For now, use a simpler approach that doesn't require the full system eval
  # TODO: Pass routerCfg from flake.nix instead

  # Hardcoded config from blue-ridge for now
  routerCfg = {
    enable = true;
    lan = {
      gateway = "192.169.1.1";
      interfaces = ["enp2s0" "enp3s0" "enp4s0"];
    };
    wan.interface = "enp1s0";
    security = {
      enableSSH = true;
      sshPort = 22;
      fail2ban = {
        enable = true;
        maxRetry = 3;
        banTime = 3600;
      };
    };
    portForwards = [
      { port = 443; destination = "192.169.1.20"; protocol = "tcp"; description = "HTTPS to pub-traefik"; }
      { port = 80; destination = "192.169.1.2"; destinationPort = 3000; protocol = "tcp"; description = "AdGuard Web UI"; }
      { port = 3000; destination = "192.169.1.40"; protocol = "tcp"; description = "Gitea Web UI"; }
      { port = 8445; destination = "192.169.1.40"; protocol = "tcp"; description = "Gitea HTTPS"; }
      { port = 22022; destination = "192.169.1.40"; protocol = "tcp"; description = "Gitea SSH"; }
    ];
    dns = {
      enable = true;
      forwarders = ["192.169.1.2"];
      enableDNSSEC = false;
    };
    zones = {
      enable = true;
      zones = {
        lan = {
          vlanId = null;
          subnet = "192.169.1.0/24";
          gateway = "192.169.1.1";
          isolation = "none";
          allowInternet = true;
          interface = "br-lan";
        };
        wifi = {
          vlanId = 10;
          subnet = "192.169.10.0/24";
          gateway = "192.169.10.1";
          isolation = "partial";
          allowInternet = true;
          interface = "br-lan.10";
        };
        iot = {
          vlanId = 20;
          subnet = "192.169.20.0/24";
          gateway = "192.169.20.1";
          isolation = "full";
          allowInternet = true;
          interface = "br-lan.20";
        };
        guest = {
          vlanId = 30;
          subnet = "192.169.30.0/24";
          gateway = "192.169.30.1";
          isolation = "full";
          allowInternet = true;
          interface = "br-lan.30";
        };
      };
      interZoneRoutes = [];
    };
  };

  # Security test script
  securityTests = pkgs.writeScriptBin "router-security-tests" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    PASSED=0
    FAILED=0
    WARNINGS=0

    pass() {
      echo -e "''${GREEN}[PASS]''${NC} $1"
      ((PASSED++))
    }

    fail() {
      echo -e "''${RED}[FAIL]''${NC} $1"
      ((FAILED++))
    }

    warn() {
      echo -e "''${YELLOW}[WARN]''${NC} $1"
      ((WARNINGS++))
    }

    info() {
      echo "[INFO] $1"
    }

    section() {
      echo ""
      echo "=================================="
      echo "$1"
      echo "=================================="
    }

    section "Router Configuration Security Audit"
    info "Analyzing blue-ridge router configuration..."
    echo ""

    # Test 1: Verify SSH is configured for LAN only
    section "Test 1: SSH Configuration"
    ${if routerCfg.security.enableSSH or false then ''
      pass "SSH is enabled for management"

      # Check if SSH port is non-standard (hardening)
      ${if (routerCfg.security.sshPort or 22) != 22 then ''
        pass "SSH port is non-standard (${toString routerCfg.security.sshPort})"
      '' else ''
        warn "SSH is on standard port 22 (consider changing for security through obscurity)"
      ''}
    '' else ''
      warn "SSH is disabled - may make remote management difficult"
    ''}

    # Test 2: fail2ban configuration
    section "Test 2: Intrusion Prevention (fail2ban)"
    ${if routerCfg.security.fail2ban.enable or false then ''
      pass "fail2ban is enabled"

      MAX_RETRY=${toString (routerCfg.security.fail2ban.maxRetry or 3)}
      if [ "$MAX_RETRY" -le 5 ]; then
        pass "fail2ban max retry is $MAX_RETRY (strict)"
      else
        warn "fail2ban max retry is $MAX_RETRY (consider lowering)"
      fi

      BAN_TIME=${toString (routerCfg.security.fail2ban.banTime or 3600)}
      if [ "$BAN_TIME" -ge 3600 ]; then
        pass "fail2ban ban time is $BAN_TIME seconds (adequate)"
      else
        warn "fail2ban ban time is only $BAN_TIME seconds (consider increasing)"
      fi
    '' else ''
      fail "fail2ban is disabled - router is vulnerable to brute force"
    ''}

    # Test 3: Port forwarding audit
    section "Test 3: Port Forwarding Exposure"
    ${if (lib.length (routerCfg.portForwards or [])) > 0 then ''
      info "Found ${toString (lib.length routerCfg.portForwards)} port forwards:"
      ${lib.concatMapStrings (fwd: ''
        info "  - Port ${toString fwd.port}/${fwd.protocol} -> ${fwd.destination}${lib.optionalString (fwd ? destinationPort) ":${toString fwd.destinationPort}"}"
        info "    Description: ${fwd.description}"

        # Warn about dangerous port forwards
        ${if fwd.port == 22 then ''
          fail "Port 22 (SSH) is forwarded to WAN - CRITICAL SECURITY RISK"
        '' else if fwd.port == 3389 then ''
          fail "Port 3389 (RDP) is forwarded to WAN - HIGH SECURITY RISK"
        '' else if fwd.port == 23 then ''
          fail "Port 23 (Telnet) is forwarded to WAN - CRITICAL SECURITY RISK"
        '' else if lib.elem fwd.port [80 443 8080 8443] then ''
          info "Port ${toString fwd.port} (HTTP/HTTPS) forwarded - ensure service is hardened"
        '' else ''
          pass "Port ${toString fwd.port} forward looks reasonable"
        ''}
      '') routerCfg.portForwards}
    '' else ''
      pass "No port forwards configured (minimizes attack surface)"
    ''}

    # Test 4: Network zones isolation
    section "Test 4: Network Zone Isolation"
    ${if routerCfg.zones.enable or false then ''
      info "Network zones enabled with ${toString (lib.length (lib.attrNames routerCfg.zones.zones))} zones"
      ${lib.concatMapStrings (zoneName: let
        zone = routerCfg.zones.zones.${zoneName};
      in ''
        info "Zone: ${zoneName}"
        info "  Isolation: ${zone.isolation}"
        info "  Internet: ${if zone.allowInternet then "allowed" else "blocked"}"

        ${if zone.isolation == "full" then ''
          pass "${zoneName} has full isolation (secure)"
        '' else if zone.isolation == "partial" then ''
          info "${zoneName} has partial isolation"
        '' else ''
          warn "${zoneName} has no isolation (can access all zones)"
        ''}

        ${if zoneName == "guest" && zone.isolation != "full" then ''
          warn "Guest zone should have full isolation"
        '' else if zoneName == "iot" && zone.isolation != "full" then ''
          warn "IoT zone should have full isolation (IoT devices are often insecure)"
        '' else ''''}
      '') (lib.attrNames routerCfg.zones.zones)}

      # Check inter-zone routing rules
      ${if (lib.length routerCfg.zones.interZoneRoutes) > 0 then ''
        info "Found ${toString (lib.length routerCfg.zones.interZoneRoutes)} inter-zone routes"
        ${lib.concatMapStrings (rule: ''
          info "  ${rule.from} -> ${lib.concatStringsSep ", " rule.to}"
          ${if rule.protocol != null && rule.ports != null then ''
            pass "Route is restricted to ${rule.protocol} ports ${lib.concatMapStringsSep "," toString rule.ports}"
          '' else if rule.protocol == null then ''
            warn "Route allows ALL protocols - consider restricting"
          '' else ''''}
        '') routerCfg.zones.interZoneRoutes}
      '' else ''
        pass "No custom inter-zone routes (zones are properly isolated)"
      ''}
    '' else ''
      warn "Network zones not enabled (consider for defense in depth)"
    ''}

    # Test 5: DNS configuration
    section "Test 5: DNS Security"
    ${if routerCfg.dns.enable or false then ''
      info "DNS forwarders: ${lib.concatStringsSep ", " routerCfg.dns.forwarders}"

      ${if routerCfg.dns.enableDNSSEC or false then ''
        pass "DNSSEC validation is enabled"
      '' else ''
        warn "DNSSEC validation is disabled"
      ''}

      # Check if using a filtering DNS like AdGuard
      ${if lib.elem "192.169.1.2" routerCfg.dns.forwarders then ''
        pass "Using AdGuard for DNS filtering (good for security/privacy)"
      '' else if lib.any (fwd: lib.hasPrefix "1.1.1" fwd || lib.hasPrefix "8.8.8" fwd) routerCfg.dns.forwarders then ''
        info "Using public DNS (${lib.concatStringsSep ", " routerCfg.dns.forwarders})"
      '' else ''''}
    '' else ''
      fail "DNS is disabled"
    ''}

    # Test 6: LAN configuration
    section "Test 6: LAN Configuration"
    info "LAN Gateway: ${routerCfg.lan.gateway}"
    info "LAN Interfaces: ${lib.concatStringsSep ", " routerCfg.lan.interfaces}"

    # Check for non-standard LAN subnet (security through obscurity)
    ${if lib.hasPrefix "192.169." routerCfg.lan.gateway then ''
      pass "Using non-standard LAN subnet (192.169.x.x)"
    '' else if lib.hasPrefix "10." routerCfg.lan.gateway then ''
      info "Using 10.x.x.x subnet (standard private range)"
    '' else if lib.hasPrefix "192.168." routerCfg.lan.gateway then ''
      warn "Using default 192.168.x.x subnet (easily guessed)"
    '' else ''''}

    # Summary
    echo ""
    echo "=================================="
    echo "Security Audit Summary"
    echo "=================================="
    echo -e "''${GREEN}Passed: $PASSED''${NC}"
    echo -e "''${RED}Failed: $FAILED''${NC}"
    echo -e "''${YELLOW}Warnings: $WARNINGS''${NC}"
    echo ""

    if [ $FAILED -gt 0 ]; then
      echo -e "''${RED}CRITICAL SECURITY ISSUES FOUND''${NC}"
      exit 1
    elif [ $WARNINGS -gt 5 ]; then
      echo -e "''${YELLOW}MULTIPLE WARNINGS - Review recommended''${NC}"
      exit 0
    else
      echo -e "''${GREEN}CONFIGURATION PASSES SECURITY AUDIT''${NC}"
      exit 0
    fi
  '';
in
  pkgs.runCommand "router-security-check"
    {
      buildInputs = [ securityTests ];
    } ''
    mkdir -p $out

    # Run the security tests
    ${securityTests}/bin/router-security-tests | tee $out/security-audit.log

    # Copy test script to output for manual runs
    cp ${securityTests}/bin/router-security-tests $out/test-script
    chmod +x $out/test-script

    echo "Security audit complete. Results in $out/security-audit.log"
  ''
