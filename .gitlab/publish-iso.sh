#!/usr/bin/env bash
# Publish the fmf live ISO: upload it to the project's generic package registry, create a release
# that links to it under a fixed asset path, and prune old images.
#
#   publish-iso.sh path/to/image.iso
#
# Run by the `build_iso` job in .gitlab-ci.yml (see docs/LIVE-ISO.md). It needs curl, jq and coreutils.
#
# From GitLab CI (always set there):
#   CI_API_V4_URL  CI_PROJECT_ID  CI_PROJECT_URL  CI_COMMIT_SHA  CI_JOB_TOKEN
# Optional:
#   GITLAB_TOKEN   a token with the `api` scope. Needed only to delete old images; without it the
#                  old ones are kept and a warning is printed.
#   KEEP           how many images to keep (default 2). A 3 GB image every month fills a free
#                  project's storage quota in a few months.
#   VERSION        the version to publish (default: today's UTC date, YYYY.MM.DD)
#   DRY_RUN=1      print what would be sent instead of calling the API
#   PACKAGES_FILE  (testing) read the package list from this JSON file instead of the API
set -euo pipefail

iso="${1:?usage: publish-iso.sh path/to/image.iso}"
[ -f "$iso" ] || { echo "publish-iso: $iso is not a file" >&2; exit 1; }

package="fmf-installer"
asset="fmf-installer-x86_64.iso" # a fixed name, so the "latest" download link never changes
version="${VERSION:-$(date -u +%Y.%m.%d)}"
keep="${KEEP:-2}"
dry="${DRY_RUN:-}"

api="${CI_API_V4_URL:?CI_API_V4_URL is not set}/projects/${CI_PROJECT_ID:?CI_PROJECT_ID is not set}"
registry="$api/packages/generic/$package/$version"
tag="iso-$version"

say() { echo "publish-iso: $*" >&2; }

# curl wrapper: in a dry run, show the call and do nothing.
call() {
  if [ -n "$dry" ]; then
    say "DRY RUN: curl $*"
  else
    curl --fail --silent --show-error --retry 3 --retry-delay 10 "$@"
  fi
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp --reflink=auto "$iso" "$work/$asset" 2>/dev/null || ln -s "$(realpath "$iso")" "$work/$asset"
(cd "$work" && sha256sum "$asset" > SHA256SUMS)
sum="$(cut -d' ' -f1 "$work/SHA256SUMS")"
size="$(du -h --apparent-size -L "$work/$asset" | cut -f1)"
say "version $version, $asset ($size), sha256 $sum"

# 1. Upload to the generic package registry.
for file in "$asset" SHA256SUMS; do
  say "uploading $file"
  call --header "JOB-TOKEN: ${CI_JOB_TOKEN:-}" --upload-file "$work/$file" "$registry/$file"
done

# 2. A release, so there is a page to read and a permanent "latest" link:
#    $CI_PROJECT_URL/-/releases/permalink/latest/downloads/<direct_asset_path>
description="$(
  cat <<EOF
The fmf live ISO, built from commit ${CI_COMMIT_SHA:-unknown}.

Boot it on a new machine for a Hyprland desktop with kitty, Brave, the Vault CLI and the tools to
partition, install and bootstrap a host from a flake. See [Install NixOS on a new machine](${CI_PROJECT_URL:-}/-/blob/${CI_COMMIT_SHA:-HEAD}/docs/INSTALL-NIXOS.md).

Check the download before you write it to a USB stick:

    sha256sum -c SHA256SUMS

    $sum  $asset
EOF
)"
release="$(
  jq -n \
    --arg name "fmf live ISO $version" \
    --arg tag "$tag" \
    --arg ref "${CI_COMMIT_SHA:-HEAD}" \
    --arg description "$description" \
    --arg iso_url "$registry/$asset" \
    --arg sum_url "$registry/SHA256SUMS" \
    --arg asset "/$asset" \
    '{
      name: $name, tag_name: $tag, ref: $ref, description: $description,
      assets: { links: [
        { name: "fmf-installer-x86_64.iso", url: $iso_url, direct_asset_path: $asset, link_type: "package" },
        { name: "SHA256SUMS", url: $sum_url, direct_asset_path: "/SHA256SUMS", link_type: "other" }
      ] }
    }'
)"
say "creating release $tag"
call --header "JOB-TOKEN: ${CI_JOB_TOKEN:-}" --header "Content-Type: application/json" \
  --data "$release" "$api/releases" > /dev/null

# 3. Prune: keep the newest $keep images and delete the rest, with their releases and tags.
if [ -z "${PACKAGES_FILE:-}" ] && [ -z "${GITLAB_TOKEN:-}" ] && [ -z "$dry" ]; then
  say "GITLAB_TOKEN is not set, so old images are not pruned (keeping all of them)"
  exit 0
fi

if [ -n "${PACKAGES_FILE:-}" ]; then
  packages="$(cat "$PACKAGES_FILE")"
else
  packages="$(call --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" \
    "$api/packages?package_type=generic&package_name=$package&order_by=created_at&sort=desc&per_page=100" || echo '[]')"
fi
[ -n "$packages" ] || packages='[]'

# The package list is newest first and includes the version just uploaded; keep the first $keep.
echo "$packages" | jq -r --arg name "$package" --argjson keep "$keep" \
  '[.[] | select(.name == $name)] | .[$keep:] | .[] | "\(.id) \(.version)"' |
  while read -r id old; do
    [ -n "$id" ] || continue
    say "pruning $old (package $id)"
    call --request DELETE --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" "$api/packages/$id" > /dev/null || say "could not delete package $id"
    call --request DELETE --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" "$api/releases/iso-$old" > /dev/null || say "no release iso-$old to delete"
    call --request DELETE --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" "$api/repository/tags/iso-$old" > /dev/null || say "no tag iso-$old to delete"
  done

say "done: ${CI_PROJECT_URL:-}/-/releases/permalink/latest/downloads/$asset"
