#!/usr/bin/env bash
# Download a release archive, verify it against the release's checksum file
# and install one binary from it.
#
#   install-tool.sh <archive-url> <checksums-url> <member-in-archive> <target-path>
#
# The checksum file is matched by the archive's file name, so both the
# "<hash>  <file>" and "<hash> *./dir/<file>" layouts work.
set -euo pipefail

archive_url=$1
checksums_url=$2
member=$3
target=$4

archive_name=${archive_url##*/}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -sSfL -o "$work/$archive_name" "$archive_url"
curl -sSfL -o "$work/checksums" "$checksums_url"

expected=$(awk -v f="$archive_name" '{ n = $2; sub(/^\*/, "", n); sub(/.*\//, "", n); if (n == f) print $1 }' "$work/checksums")
if [[ -z $expected ]]; then
  echo "no checksum for $archive_name in $checksums_url" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$work/$archive_name" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$work/$archive_name" | cut -d' ' -f1)
fi
if [[ $actual != "$expected" ]]; then
  echo "checksum mismatch for $archive_name: expected $expected, got $actual" >&2
  exit 1
fi

tar -xzf "$work/$archive_name" -C "$work" "$member"
mkdir -p "$(dirname "$target")"
install -m 0755 "$work/$member" "$target"
echo "installed $target"
