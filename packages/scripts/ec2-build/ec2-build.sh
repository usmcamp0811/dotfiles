# ec2-build: run a Nix command with a throwaway aarch64 EC2 instance as its remote builder.
#
#   ec2-build [--env-file FILE] [--keep] [--] COMMAND [ARGS...]
#   ec2-build [--env-file FILE] --cleanup
#   ec2-build --list
#
# @TF_CONFIG@ is replaced at build time with the terranix-generated configuration.

TF_CONFIG='@TF_CONFIG@'

usage() {
  cat <<'EOF'
Usage:
  ec2-build [--env-file FILE] [--keep] [--] COMMAND [ARGS...]
      Create an aarch64 NixOS instance on EC2, run COMMAND with it as a remote builder for
      aarch64-linux, then destroy the instance. Exits with COMMAND's status.
  ec2-build [--env-file FILE] --cleanup
      Destroy everything left behind by earlier runs (killed runs, --keep, failed destroys).
  ec2-build --list
      List the runs that still have resources.

Options:
  --env-file FILE  Source FILE (KEY=value lines) before anything else. Its values override the
                   environment. Default: $EC2_BUILD_ENV_FILE, if set.
  --keep           Do not destroy the instance at the end (debugging). Remove it later with
                   --cleanup.

Environment (all optional except AWS credentials):
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, AWS_PROFILE
                             Credentials, read by the AWS provider as usual.
  EC2_BUILD_REGION           Region (default: $AWS_REGION, $AWS_DEFAULT_REGION, else us-east-1).
  EC2_BUILD_INSTANCE_TYPE    Graviton instance type (default: c7g.4xlarge).
  EC2_BUILD_VOLUME_GB        Root disk size in GB (default: 100).
  EC2_BUILD_MAX_MINUTES      The instance shuts itself down (and is terminated) after this many
                             minutes, whatever happens to this script (default: 240).
  EC2_BUILD_MAX_JOBS         Concurrent builds sent to the instance (default: 4).
  EC2_BUILD_AMI              Use this AMI id instead of looking one up.
  EC2_BUILD_AMI_NAME         Name pattern of the official NixOS AMI (default: nixos/26.05*).
  EC2_BUILD_SSH_CIDR         Who may SSH in (default: this machine's public IPv4 address /32).
  EC2_BUILD_VPC_ID, EC2_BUILD_SUBNET_ID
                             Use these instead of the default VPC (set both).
  EC2_BUILD_STATE_DIR        Where runs are kept (default: $XDG_STATE_HOME/ec2-build).

Your user must be trusted by the Nix daemon (nix.settings.trusted-users), otherwise the daemon
ignores the builder and the build fails or runs locally.

Example:
  nix run .#ec2-build -- --env-file ~/.config/ec2-build.env -- \
    nix build .#nixosConfigurations.pikvm.config.system.build.toplevel
EOF
}

log() { printf 'ec2-build: %s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# --- arguments -------------------------------------------------------------------------------------

mode=run
keep=${EC2_BUILD_KEEP:-0}
env_file=${EC2_BUILD_ENV_FILE:-}
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --env-file)
    [ $# -ge 2 ] || die "--env-file needs a file"
    env_file=$2
    shift 2
    ;;
  --env-file=*)
    env_file=${1#*=}
    shift
    ;;
  --keep)
    keep=1
    shift
    ;;
  --cleanup)
    mode=cleanup
    shift
    ;;
  --list)
    mode=list
    shift
    ;;
  --)
    shift
    break
    ;;
  -*) die "unknown option: $1 (put the command after --)" ;;
  *) break ;;
  esac
done

if [ -n "$env_file" ]; then
  [ -r "$env_file" ] || die "cannot read env file: $env_file"
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
fi

state_root=${EC2_BUILD_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ec2-build}
export TF_IN_AUTOMATION=1 CHECKPOINT_DISABLE=1

tofu_in() {
  local dir=$1
  shift
  tofu -chdir="$dir" "$@"
}

# Destroy one run's resources; remove its directory only if that worked.
destroy_run() {
  local dir=$1
  if [ ! -f "$dir/terraform.tfstate" ]; then
    rm -rf "$dir"
    return 0
  fi
  log "destroying $(basename "$dir")"
  if tofu_in "$dir" init -input=false >/dev/null &&
    tofu_in "$dir" destroy -auto-approve -input=false -var-file=vars.tfvars.json >&2; then
    rm -rf "$dir"
  else
    log "destroy FAILED; resources may still exist. State kept in $dir"
    log "retry with: ec2-build --cleanup   (or look for EC2 tag ManagedBy=ec2-build)"
    return 1
  fi
}

case "$mode" in
list)
  [ -d "$state_root" ] && find "$state_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  exit 0
  ;;
cleanup)
  status=0
  if [ -d "$state_root" ]; then
    for dir in "$state_root"/*/; do
      [ -d "$dir" ] || continue
      destroy_run "${dir%/}" || status=1
    done
  fi
  exit "$status"
  ;;
esac

[ $# -gt 0 ] || {
  usage >&2
  exit 2
}

# --- preflight (before anything costs money) -------------------------------------------------------

command -v nix >/dev/null || die "nix is not on PATH"
# Only a trusted user may hand the daemon a `builders` setting; an untrusted one gets a warning
# from nix and the setting is dropped, so check before paying for an instance.
if [ "${EC2_BUILD_SKIP_TRUST_CHECK:-0}" != 1 ]; then
  # (not `.trusted // "unknown"`: jq's // treats false as missing)
  trusted=$(nix store info --json 2>/dev/null |
    jq -r 'if has("trusted") then .trusted | tostring else "unknown" end' || echo unknown)
  case "$trusted" in
  1 | true) ;;
  0 | false)
    die "the Nix daemon does not trust $(id -un), so it would ignore the EC2 builder.
  Add the user to nix.settings.trusted-users (NixOS) and restart nix-daemon, or set
  EC2_BUILD_SKIP_TRUST_CHECK=1 to try anyway."
    ;;
  *) log "warning: could not tell whether the Nix daemon trusts you; continuing" ;;
  esac
fi

region=${EC2_BUILD_REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}}
instance_type=${EC2_BUILD_INSTANCE_TYPE:-c7g.4xlarge}
volume_gb=${EC2_BUILD_VOLUME_GB:-100}
max_minutes=${EC2_BUILD_MAX_MINUTES:-240}
max_jobs=${EC2_BUILD_MAX_JOBS:-4}

if [ -n "${EC2_BUILD_SSH_CIDR:-}" ]; then
  ssh_cidr=$EC2_BUILD_SSH_CIDR
else
  my_ip=$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]') ||
    die "could not find this machine's public IP; set EC2_BUILD_SSH_CIDR"
  ssh_cidr="$my_ip/32"
fi

# --- create ----------------------------------------------------------------------------------------

run_id="$(date -u +%Y%m%d-%H%M%S)-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
run_dir="$state_root/$run_id"
mkdir -p "$state_root"
mkdir -m 700 "$run_dir"

# shellcheck disable=SC2329 # called from the EXIT trap
finish() {
  local status=$?
  trap - EXIT INT TERM
  if [ "$keep" = 1 ]; then
    log "--keep: instance left running (run $run_id). SSH:"
    log "  ssh -i $run_dir/id_ed25519 -o UserKnownHostsFile=$run_dir/known_hosts root@${ip:-?}"
    log "remove it with: ec2-build --cleanup"
  else
    destroy_run "$run_dir" || status=1
  fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

ssh-keygen -q -t ed25519 -N '' -C "ec2-build-$run_id" -f "$run_dir/id_ed25519"
install -m 600 "$TF_CONFIG" "$run_dir/config.tf.json"
jq -n \
  --arg region "$region" \
  --arg run_id "$run_id" \
  --arg ssh_public_key "$(cat "$run_dir/id_ed25519.pub")" \
  --arg ssh_cidr "$ssh_cidr" \
  --arg instance_type "$instance_type" \
  --argjson volume_gb "$volume_gb" \
  --argjson max_minutes "$max_minutes" \
  --arg ami_id "${EC2_BUILD_AMI:-}" \
  --arg ami_name "${EC2_BUILD_AMI_NAME:-nixos/26.05*}" \
  --arg vpc_id "${EC2_BUILD_VPC_ID:-}" \
  --arg subnet_id "${EC2_BUILD_SUBNET_ID:-}" \
  '{region: $region, run_id: $run_id, ssh_public_key: $ssh_public_key, ssh_cidr: $ssh_cidr,
    instance_type: $instance_type, volume_gb: $volume_gb, max_minutes: $max_minutes,
    ami_id: $ami_id, ami_name: $ami_name,
    vpc_id: (if $vpc_id == "" then null else $vpc_id end),
    subnet_id: (if $subnet_id == "" then null else $subnet_id end)}' \
  >"$run_dir/vars.tfvars.json"

log "run $run_id: $instance_type in $region, SSH from $ssh_cidr, self-destructs after ${max_minutes}m"
tofu_in "$run_dir" init -input=false >/dev/null
tofu_in "$run_dir" apply -auto-approve -input=false -var-file=vars.tfvars.json >&2
ip=$(tofu_in "$run_dir" output -raw public_ip)
[ -n "$ip" ] || die "the instance has no public IP (a subnet without auto-assign? set EC2_BUILD_SUBNET_ID)"
log "instance $(tofu_in "$run_dir" output -raw instance_id) at $ip ($(tofu_in "$run_dir" output -raw ami_id))"

# --- wait for SSH and pin the host key -------------------------------------------------------------

# Trust on first use: the key ssh-keyscan sees is pinned for the rest of the run, for this script's
# own ssh and (base64, in the builder line) for the Nix daemon's.
host_key=
for _ in $(seq 1 60); do
  host_key=$(ssh-keyscan -T 5 -t ed25519 "$ip" 2>/dev/null | awk '$2 == "ssh-ed25519" {print $2" "$3; exit}') || true
  [ -n "$host_key" ] && break
  sleep 5
done
[ -n "$host_key" ] || die "no SSH on $ip after 5 minutes"
printf '%s %s\n' "$ip" "$host_key" >"$run_dir/known_hosts"

ssh_opts=(-i "$run_dir/id_ed25519" -o IdentitiesOnly=yes -o UserKnownHostsFile="$run_dir/known_hosts"
  -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -o BatchMode=yes)
ready=0
for _ in $(seq 1 30); do
  if ssh "${ssh_opts[@]}" "root@$ip" nix-store --version >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 5
done
[ "$ready" = 1 ] || die "SSH as root to $ip did not work"
log "builder ready: $(ssh "${ssh_opts[@]}" "root@$ip" 'echo "$(nproc) CPUs, $(nix-store --version)"')"

# --- run the command -------------------------------------------------------------------------------

# Machine line fields: URI, systems, SSH key, max jobs, speed factor, supported features,
# mandatory features, base64 host key. The key file is read by the daemon (root), not by you.
builder="ssh-ng://root@$ip aarch64-linux $run_dir/id_ed25519 $max_jobs 1 big-parallel,benchmark - $(printf '%s' "$host_key" | base64 -w0)"
NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}builders = $builder
builders-use-substitutes = true"
export NIX_CONFIG

log "running: $*"
set +e
"$@"
cmd_status=$?
set -e
log "command exited with $cmd_status"
exit "$cmd_status"
