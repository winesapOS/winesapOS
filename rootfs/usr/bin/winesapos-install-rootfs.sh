#!/bin/bash

set -x

# Install the winesapOS root file system into the target directory that the Calamares installer has
# already partitioned and mounted.
#
# The running live media is copied instead of a release tarball being downloaded. The installation
# is then always the same version as the media that it was installed from, no matter whether that
# media is a release image or a locally built one, and no network access is needed.
#
# The Calamares 'unpackfs' module cannot be used for this because it mounts the source and copies
# from it, which only works for a file system image such as SquashFS.

winesapos_install_dir="${1}"

if [[ -z "${winesapos_install_dir}" ]]; then
    echo "ERROR: No target directory was provided."
    exit 1
fi

if ! mountpoint -q "${winesapos_install_dir}"; then
    echo "ERROR: ${winesapos_install_dir} is not a mount point."
    exit 1
fi

# Calamares cannot create nested Btrfs subvolumes so this one is created manually. The rest are
# created by the Calamares 'mount' module.
if ! btrfs subvolume show "${winesapos_install_dir}/home/.snapshots" &> /dev/null; then
    btrfs subvolume create "${winesapos_install_dir}/home/.snapshots"
fi

echo "INFO: Copying the winesapOS installation (this will take a long time)..."

# Virtual file systems, the RAM file systems, and the removable media of the live environment hold
# nothing that belongs in the installation. The Calamares target is mounted underneath "/tmp" so
# excluding that directory is also what stops this from copying into itself.
#
# Btrfs snapshots are excluded because they are copy-on-write on the live media but would be copied
# as complete duplicates here. The subvolumes themselves are kept so that Snapper still works.
#
# The swap file is excluded because it is large and the first-time setup creates a new one.
rsync_excludes=(
  --exclude="/dev/*"
  --exclude="/proc/*"
  --exclude="/sys/*"
  --exclude="/run/*"
  --exclude="/tmp/*"
  --exclude="/var/tmp/*"
  --exclude="/var/log/*"
  --exclude="/var/cache/pacman/pkg/*"
  --exclude="/mnt/*"
  --exclude="/media/*"
  --exclude="/lost+found"
  --exclude="/.snapshots/*"
  --exclude="/home/.snapshots/*"
  --exclude="/swap/*"
  --exclude="${winesapos_install_dir}"
)

# Avoid overriding the UEFI files of an existing Linux installation.
# shellcheck disable=SC2010
if ls "${winesapos_install_dir}"/boot/efi/EFI/ 2> /dev/null | grep -q -P "(fedora|ubuntu)"; then
    rsync_excludes+=(--exclude="/boot/efi/EFI/BOOT")
fi

if ! rsync --archive --hard-links --acls --xattrs --sparse --numeric-ids \
     "${rsync_excludes[@]}" / "${winesapos_install_dir}"/; then
    echo "ERROR: Failed to copy the winesapOS installation."
    exit 1
fi

sync
