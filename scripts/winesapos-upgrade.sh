#!/bin/zsh

if [[ "${WINESAPOS_DEBUG}" == "true" ]]; then
    set -x
fi

exec > >(tee /etc/winesapos/upgrade_${START_TIME}.log) 2>&1
echo "Start time: $(date --iso-8601=seconds)"

VERSION_NEW="3.1.0-dev"

# Update the repository cache.
pacman -Sy
# Update the trusted repository keyrings.
pacman --noconfirm -S archlinux-keyring manjaro-keyring

echo "Running 3.0.0 to 3.1.0 upgrades..."
echo "Running 3.0.0 to 3.1.0 upgrades complete."

# Record the original and new versions.
echo "VERSION_ORIGNIAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
echo "End time: $(date --iso-8601=seconds)"
