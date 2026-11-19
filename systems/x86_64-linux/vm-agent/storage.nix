# Storage and store layout for vm-agent (fmf.host; spec: docs/HOST-MODEL.md, Phase 3).
{...}: {
  fmf.host = {
    derive = true;
    nixStore = "persistent";
    standardShares.rootPassword = false;
    storage = {
      # The agent's own disposable home: shell history, opencode sessions, clones.
      agent-home = {
        mountPoint = "/home/mcamp";
        hostPath = "/persist/vm-data/vm-agent/home";
        mode = "0700";
        owner = "10000";
        group = "10000";
      };
      # The hypervisor user's real ~/code, shared at the same path (uid 10000 on both sides).
      mcamp-code = {
        mountPoint = "/home/mcamp/code";
        hostPath = "/home/mcamp/code";
        createDirectory = false;
      };
    };
  };
}
