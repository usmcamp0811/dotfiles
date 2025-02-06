{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.login_attempts;
in {
  options.campground.stig.login_attempts = with types; {
    enable = mkBoolOpt false "Enable STIG Login Attempt Restrictions";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = mkIf cfg.enable {
    campground.stig.srg = [
      "SRG-OS-000021-GPOS-00005"
      "SRG-OS-000329-GPOS-00128"
      "SRG-OS-000470-GPOS-00214"
    ];
    campground.stig.cci = [ "CCI-000044" "CCI-002238" "CCI-000172" ];

    security.pam.services =
      let
        pamfile = ''
          auth required pam_faillock.so preauth silent audit deny=3 fail_interval=900 unlock_time=0
          auth sufficient pam_unix.so nullok try_first_pass
          auth [default=die] pam_faillock.so authfail audit deny=3 fail_interval=900 unlock_time=0
          auth sufficient pam_faillock.so authsucc

          account required pam_faillock.so
        '';
      in
      {
        login.text = pkgs.lib.mkDefault pamfile;
        sshd.text = pkgs.lib.mkDefault pamfile;
      };
  };
}
