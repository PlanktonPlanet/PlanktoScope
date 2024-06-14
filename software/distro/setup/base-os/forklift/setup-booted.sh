#!/bin/bash -eux
# The Forklift pallet github.com/PlanktoScope/pallet-standard provides the standard configuration of
# Forklift package deployments of Docker containerized applications, OS config files, and systemd
# system services for the PlanktoScope software distribution. This script integrates that pallet
# into the PlanktoScope OS's filesystem by installing Forklift and providing some systemd units
# which set up bind mounts and overlay filesystems to bootstrap the configs managed by Forklift.

config_files_root=$(dirname $(realpath $BASH_SOURCE))

# Prepare to apply the local pallet

# Note: the pi user will only be able to run `forklift stage plan` and `forklift stage cache-img`
# without root permissions after a reboot, so we may need `sudo -E` here; I had tried running
# `newgrp docker` in the script to avoid the need for `sudo -E here`, but it doesn't work in the
# script here (even though it works after the script finishes, before rebooting):
FORKLIFT="forklift"
if [ -S /var/run/docker.sock ] && \
  ! sudo -E docker ps 2>&1 > /dev/null && \
  ! sudo systemctl start docker.socket docker.service
then
  echo "Error: couldn't start docker!"
  journalctl --no-pager -u docker.socket
  journalctl --no-pager -u docker.service
  sudo findmnt -lo source,target,fstype,options -t cgroup,cgroup2
  # Note: iptables/iptables-nft won't work if run using qemu-aarch64-static
  # (see https://github.com/multiarch/qemu-user-static/issues/191 for details), e.g. via a
  # systemd-nspawn container. But if we run the systemd-nspawn container on an aarch64 host, it
  # should probably work - so once GitHub rolls out arm64 runner for open-source projects, we may
  # be able to run booted setup (i.e. with Docker) in a systemd-nspawn container rather than a
  # QEMU VM; that will probably make the booted setup step much faster.
  sudo iptables -L || sudo lsmod
  exit 1
fi
if ! docker ps 2>&1 > /dev/null; then
  FORKLIFT="sudo -E forklift"
fi

# Move container images used by the local pallet from the pre-cache to the Docker daemon

echo "Downloading temporary tools to load pre-downloaded container images into Docker..."
tmp_bin="$(mktemp -d --tmpdir=/tmp bin.XXXXXXX)"
"$config_files_root/download-rush.sh" "$tmp_bin"

echo "Loading pre-downloaded container images into Docker..."
forklift plt ls-img | "$tmp_bin/rush" \
  "$config_files_root/transfer-precached-image.sh" {} "$HOME/.cache/forklift/containers/docker-archives"

# Applying the staged pallet (i.e. making Docker instantiate all the containers) significantly
# decreases first-boot time, by up to 30 sec for github.com/PlanktoScope/pallet-standard.
if ! $FORKLIFT stage apply; then
  echo "The staged pallet couldn't be applied; we'll try again now..."
  # Reset the "apply-failed" status of the staged pallet to apply:
  forklift stage set-next --no-cache-img next
  if ! $FORKLIFT stage apply; then
    echo "Warning: the next staged pallet could not be successfully applied. We'll try again on the next boot, since the pallet might require some files which will only be created during the next boot."
    # Reset the "apply-failed" status of the staged pallet to apply:
    forklift stage set-next --no-cache-img next
    echo "Checking the plan for applying the staged pallet..."
    $FORKLIFT stage plan
    # Note: we don't run forklift stage cache-img because we had already loaded all necessary images
    # from the pre-cache, and we want to avoid talking to the network if we're in a QEMU VM (since
    # that often causes failure with a network TLS handshake timeout).
  fi
fi

# Prepare to apply the pallet on future boots, too
sudo systemctl unmask forklift-apply.service
