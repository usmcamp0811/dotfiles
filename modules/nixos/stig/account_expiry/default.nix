{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.account_expiry;
in {
  options.campground.stig.account_expiry = with types; {
    enable = mkBoolOpt config.campground.stig.enable
      "Enable STIG account expiration enforcement";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = mkIf cfg.enable {
    campground.stig.srg =
      [ "SRG-OS-000002-GPOS-00002" "SRG-OS-000123-GPOS-00064" ];
    campground.stig.cci = [ "CCI-000016" "CCI-001682" ];

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
