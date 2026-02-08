{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.openwrt-backup;
  filelist = builtins.readFile ./filelist.txt;
  backup = pkgs.writeShellScriptBin "backup.sh" ''
    # Check if the correct number of arguments have been provided
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <filelist> <target_directory>"
        exit 1
    fi

    # The file containing the list of file paths
    FILELIST="$1"

    # The target directory
    TARGETDIR="$2"

    # Check if the target directory is a git repository
    if ${pkgs.git}/bin/git -C "$(dirname "$TARGETDIR")" rev-parse --git-dir > /dev/null 2>&1; then
        echo "The parent directory of $TARGETDIR is a Git repository."
    else
        echo "The parent directory of $TARGETDIR is not a Git repository. Please verify your setup."
        exit 1
    fi

    # Loop over the list of files
    while read -r filepath
    do
        # Construct the destination file path
        # destination="${TARGETDIR}${filepath}"
        destination="$(echo "${TARGETDIR}" | ${pkgs.gnused}/bin/sed 's:/*$::')/$(echo ${filepath} | cut -d':' -f2)"
        destination_dir=$(dirname "${destination}")

        # Create directory structure in target directory
        mkdir -p "${destination_dir}"

        echo ${destination_dir}
        # Copy the file
        ${pkgs.rsync}/bin/rsync -aI ${filepath} ${destination}

    done < "$FILELIST"

    # Change directory to the git repository
    cd "$TARGETDIR"

    # Stage all changes
    ${pkgs.git}/bin/git add .

    # Create a commit with the current date and time
    COMMITMSG="Automated commit at $(date +%Y-%m-%d\ %H:%M:%S)"
    ${pkgs.git}/bin/git commit -m "$COMMITMSG"
  '';
in {
  options.fmf.services.openwrt-backup = with types; {
    enable = mkBoolOpt false "Enable an Nginx Proxy;";
    backupPath =
      mkOpt str "/webb/backups/openwrt-backups/campnet-backup"
      "Place to backup OpenWRT to.";
  };

  config = mkIf cfg.enable {
    systemd.services.backupOpenWRT = {
      description = "Get ZFS Passphrase from Vault and Encrypt with Clevis";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash ${backup}/bin/backup.sh ${filelist} ${cfg.backupPath}";
        # ExecStart = "${pkgs.bash}/bin/bash /config/test.sh";
      };
      wantedBy = ["multi-user.target"];
    };
  };
}
