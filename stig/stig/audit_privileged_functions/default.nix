{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_privileged_functions";
  srgList = [
    "SRG-OS-000042-GPOS-00020"
    "SRG-OS-000062-GPOS-00031"
    "SRG-OS-000064-GPOS-00033"
    "SRG-OS-000365-GPOS-00152"
    "SRG-OS-000392-GPOS-00172"
    "SRG-OS-000471-GPOS-00215"
    "SRG-OS-000755-GPOS-00220"
  ];
  cciList = [
    "CCI-000135"
    "CCI-000169"
    "CCI-000172"
    "CCI-003938"
    "CCI-002884"
    "CCI-004188"
  ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv "
      "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv "
    ];
  };
}
