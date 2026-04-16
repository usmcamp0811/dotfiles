# Changelog

All notable changes to the Jitsi Meet NixOS module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-15

### Added
- Initial release of Jitsi Meet NixOS module for fmf-flake
- Full Jitsi Meet stack support:
  - Jitsi Meet web interface
  - Jitsi Videobridge for media routing
  - Jicofo (Conference Focus) for meeting management
  - Prosody XMPP server for signaling
- Integrated Coturn TURN server for WebRTC connectivity
- HashiCorp Vault integration for secret management via vault-agent
- Automatic SSL certificate management via ACME/Let's Encrypt
- Nginx reverse proxy integration
- Automatic firewall configuration for all required ports
- Extensive configuration options for customization
- Support for both Vault KV v1 and v2
- Comprehensive documentation:
  - README.md with full usage guide
  - VAULT_SETUP.md with Vault configuration instructions
  - TEST.md with testing procedures
  - example.nix with configuration examples
  - CHANGELOG.md (this file)

### Features
- **Vault Integration**:
  - Automatic secret retrieval via vault-agent
  - Support for TURN_SECRET, COMPONENT_SECRET, and VIDEOBRIDGE_SECRET
  - Configurable Vault paths and KV versions
  - Automatic service restart on secret changes

- **Security**:
  - ACME/Let's Encrypt automatic SSL certificates
  - Secure secret management via Vault
  - Firewall configuration with minimal required ports
  - TLS configuration for Coturn TURN server

- **Customization**:
  - Extensive interface configuration options
  - Meeting behavior customization
  - P2P and TURN server configuration
  - Extra configuration injection support

- **Monitoring & Debugging**:
  - Systemd service integration
  - Comprehensive logging
  - Service health checks
  - Easy troubleshooting with clear error messages

### Configuration Options
- `enable` - Enable/disable Jitsi Meet
- `hostName` - Hostname for Jitsi Meet instance
- `nginx.*` - Nginx reverse proxy configuration
- `coturn.*` - Coturn TURN server configuration
- `videobridge.*` - Jitsi Videobridge configuration
- `jicofo.*` - Jicofo configuration
- `prosody.*` - Prosody XMPP server configuration
- `interfaceConfig` - Web interface customization
- `config` - Meeting behavior configuration
- `vault.*` - Vault integration settings
- `acme.*` - ACME/Let's Encrypt configuration
- `extraConfig` - Additional JavaScript configuration

### Dependencies
- NixOS 25.05 or later
- nixpkgs with Jitsi Meet packages
- HashiCorp Vault (optional, but recommended)
- DeterminateSystems vault-service (for Vault integration)

### Compatibility
- Follows fmf-flake naming conventions (`fmf.services.*`)
- Uses fmf-flake lib helpers (`mkOpt`, `mkBoolOpt`)
- Integrates with existing fmf.services.vault-agent configuration
- Compatible with snowfall-lib flake structure

### Documentation
- Comprehensive README with usage examples
- Vault setup guide with security best practices
- Testing guide with validation procedures
- Example configurations for common scenarios

### Known Limitations
- Requires manual Vault secret setup before first deployment
- ACME requires valid DNS and public IP address
- Coturn requires proper network configuration for NAT traversal

### Future Enhancements
Planned for future releases:
- [ ] Jibri integration for recording/streaming
- [ ] SIP gateway integration
- [ ] Prometheus metrics exporter
- [ ] Grafana dashboard
- [ ] Multi-videobridge support for scaling
- [ ] LDAP/SSO authentication integration
- [ ] Custom branding support
- [ ] Automated backup/restore

## Guidelines for Future Changes

### Adding Features
1. Maintain backward compatibility
2. Add new options under appropriate sections
3. Document all new options in README.md
4. Add examples to example.nix
5. Update TEST.md with new test procedures
6. Follow fmf-flake naming conventions

### Security Updates
1. Document security implications in changelog
2. Update VAULT_SETUP.md if secret handling changes
3. Test with both Vault KV v1 and v2
4. Verify firewall rules remain minimal

### Breaking Changes
1. Bump major version
2. Clearly document migration path
3. Provide compatibility layer when possible
4. Update all documentation

### Version Numbering
- **Major** (X.0.0): Breaking changes, significant new features
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, documentation updates

---

[1.0.0]: Initial release
