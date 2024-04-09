#!/bin/bash -eux
# The Forklift pallet github.com/PlanktoScope/pallet-standard provides the standard configuration of
# Forklift package deployments of Docker containerized applications, OS config files, and systemd
# system services for the PlanktoScope software distribution.

config_files_root=$(dirname $(realpath $BASH_SOURCE))

# Install Forklift

forklift_version="0.6.0"
pallet_path="github.com/PlanktoScope/pallet-standard"
pallet_version="v2024.0.0-alpha.1"

curl -L "https://github.com/PlanktoScope/forklift/releases/download/v$forklift_version/forklift_${forklift_version}_linux_arm.tar.gz" \
  | sudo tar -C /usr/bin -xz forklift
sudo mv /usr/bin/forklift "/usr/bin/forklift-${forklift_version}"
sudo ln -s "/usr/bin/forklift-${forklift_version}" /usr/bin/forklift

# Set up local pallet

workspace="$HOME"
forklift --workspace $workspace plt clone --force $pallet_path@$pallet_version
forklift --workspace $workspace plt cache-repo

# Note: this command must run with sudo even though the pi user has been added to the docker
# usergroup, because that change only works after starting a new login shell; and `newgrp docker`
# doesn't work either:
sudo -E forklift --workspace $workspace plt cache-img --parallel # to save disk space, we don't cache images used by disabled package deployments

# Note: the pallet must be applied during each startup because we're using Docker Compose rather
# than Swarm Mode:
file="/usr/lib/systemd/system/forklift-apply.service"
sudo cp "$config_files_root$file" "$file"
sudo systemctl enable forklift-apply.service

# Set up overlay for /etc
file="/usr/lib/systemd/system/run-mount-overlays-etc.mount"
sudo cp "$config_files_root$file" "$file"
sudo systemctl enable run-mount-overlays-etc.mount
file="/usr/lib/systemd/system/etc.mount"
sudo cp "$config_files_root$file" "$file"
sudo systemctl enable etc.mount
sudo mkdir -p /var/lib/overlays/overrides/etc
sudo mkdir -p /var/lib/overlays/workdirs/etc
# TODO: remove this placeholder once we automatically generate it:
mkdir -p /home/pi/.local/share/forklift/export/next/overlays/etc
