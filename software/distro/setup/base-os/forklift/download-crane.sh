#!/bin/bash -eu
parent="$1"

config_files_root=$(dirname $(realpath $BASH_SOURCE))
version="$(cat "$config_files_root/crane-version")"
arch="$(uname -m | sed -e 's~amd64~x86_64~' -e 's~aarch64~arm64~')"
tmp_bin="$(mktemp --directory bin.XXXXXXX)"

echo "Downloading crane v$crane_version ($arch) to $tmp_bin/crane..."
curl -L "https://github.com/google/go-containerregistry/releases/download/v$version/go-containerregistry_Linux_${arch}.tar.gz" \
  | tar -C "$tmp_bin" -xz crane

echo "Moving $tmp_bin/crane to $parent/crane..."
mv "$tmp_bin/crane" "$parent/crane" || sudo mv "$tmp_bin/crane" "$parent/crane"
