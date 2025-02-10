{ lib, config, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.stig;
  # allStigs = removeAttrs cfg [ "enable" ];
  # activeStigs = filterAttrs (_: v: v.enable or false) allStigs;
  # inactiveStigs = filterAttrs (_: v: !(v.enable or false)) allStigs;
  #
  # aggregateValues = key:
  #   unique
  #     (concatLists (map (stig: stig.${key} or [ ]) (attrValues activeStigs)));
  #
  # # Collect values but DO NOT merge yet
  # aggregatedConfigs = map (stig: stig.config or { }) (attrValues activeStigs);
  #
  # # Lazy merging function - only executes when needed
  # mergedConfig = mkMerge aggregatedConfigs;
in
{

  options.campground.stig = {
    enable = mkEnableOption "Campground STIG aggregation";
    active = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Aggregated active STIGs.";
      internal = true;
    };
    inactive = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Aggregated inactive STIGs.";
      internal = true;
    };
  };
  config = mkIf cfg.enable {
    campground.stig = {
      account_expiry.enable = mkDefault true;
      audit.enable = mkDefault true;
      audit_account_events.enable = mkDefault true;
      # audit_account_fips.enable = mkDefault true;
      audit_account_modifications.enable = mkDefault true;
      audit_backlog_limit.enable = mkDefault true;
      audit_chmod_operations.enable = mkDefault true;
      audit_chown_operations.enable = mkDefault true;
      audit_cron_modifications.enable = mkDefault true;
      # audit_failure_handling.enable = mkDefault true;
      audit_file_deletion.enable = mkDefault true;
      audit_file_operations.enable = mkDefault true;
      audit_kernel_modules.enable = mkDefault true;
      audit_log_directory_permissions.enable = mkDefault true;
      audit_log_file_permissions.enable = mkDefault true;
      audit_log_group_ownership.enable = mkDefault true;
      audit_log_offloading.enable = mkDefault true;
      audit_log_ownership.enable = mkDefault true;
      audit_log_permissions.enable = mkDefault true;
      audit_module_change.enable = mkDefault true;
      audit_module_load.enable = mkDefault true;
      audit_mount_syscall.enable = mkDefault true;
      audit_package_installed.enable = mkDefault true;
      audit_pre_daemon.enable = mkDefault true;
      audit_privileged_functions.enable = mkDefault true;
      audit_remote_authentication.enable = mkDefault true;
      audit_security_logging.enable = mkDefault true;
      audit_service_package.enable = mkDefault true;
      audit_storage_monitoring.enable = mkDefault true;
      audit_storage_notification.enable = mkDefault true;
      audit_unsuccessful_file_access.enable = mkDefault true;
      banner.enable = mkDefault true;
      config_security.enable = mkDefault true;
      disk_encryption.enable = mkDefault true;
      # encryption_password_wireless.enable = mkDefault true;
      fips_compliant_ciphers.enable = mkDefault true;
      fips_crypto_compliance.enable = mkDefault true;
      fips_password_security.enable = mkDefault true;
      firewall.enable = mkDefault true;
      kernel_hardening_audit.enable = mkDefault true;
      login_attempts.enable = mkDefault true;
      mfa_root_restrictions_usbguard.enable = mkDefault true;
      password_complexity.enable = mkDefault true;
      pki_auth_password_complexity.enable = mkDefault true;
      remote_access_encryption.enable = mkDefault true;
      remote_access_monitoring.enable = mkDefault true;
      security_config_protection.enable = mkDefault true;
      security_hardening.enable = mkDefault true;
      session_limit.enable = mkDefault true;
      session_lock.enable = mkDefault true;
      session_lock_package.enable = mkDefault true;
      ssh_memory_protection.enable = mkDefault true;
      ssh_timeout_data_protection.enable = mkDefault true;
      syslog_directory_permissions.enable = mkDefault true;
      syslog_group_configuration.enable = mkDefault true;
      syslog_group_ownership.enable = mkDefault true;
      syslog_log_permissions.enable = mkDefault true;
      # syslog_ng_directory_permissions.enable = mkDefault true;
      syslog_owner_configuration.enable = mkDefault true;
      time_sync_security.enable = mkDefault true;
      unique_uid_mfa.enable = mkDefault true;
      usbguard_stickybit_dos_ssh.enable = mkDefault true;
      wireless_bluetooth_audit_time.enable = mkDefault true;
      wireless_encryption.enable = mkDefault true;
    };
  };
}
