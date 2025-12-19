{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
mkStigModule {
  inherit config;
  name = "account_expiry";
  srgList = [ "SRG-OS-000002-GPOS-00002" "SRG-OS-000123-GPOS-00064" ];
  cciList = [ "CCI-000016" "CCI-001682" ];
  stigConfig = {
    systemd.services.expire-accounts = {
      description =
        "Ensure emergency and temporary accounts expire within 72 hours";
      script = ''
        for user in $(getent passwd | cut -d: -f1); do
          if sudo chage -l "$user" | grep -q "never"; then
            sudo chage -E "$(date -d "+3 days" +%Y-%m-%d)" "$user"
          fi
        done
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
