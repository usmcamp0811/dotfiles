{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "remote_access_encryption";
  srgList = [ "SRG-OS-000033-GPOS-00014" ];
  stigConfig = {
    services.openssh.settings = {
      Ciphers = [ "aes256-gcm@openssh.com" "aes256-ctr" ];
      KexAlgorithms = [ "curve25519-sha256" "curve25519-sha256@libssh.org" ];
      Macs =
        [ "hmac-sha2-512-etm@openssh.com" "hmac-sha2-256-etm@openssh.com" ];
    };
  };
}
