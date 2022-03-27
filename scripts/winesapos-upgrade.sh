#!/bin/zsh

if [[ "${WINESAPOS_DEBUG}" == "true" ]]; then
    set -x
fi

exec > >(tee /etc/winesapos/upgrade_${START_TIME}.log) 2>&1
echo "Start time: $(date --iso-8601=seconds)"

VERSION_NEW="3.0.0"

# Update the repository cache.
pacman -Sy
# Update the trusted repository keyrings.
pacman --noconfirm -S archlinux-keyring manjaro-keyring

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades..."

echo "Upgrading exFAT partition to work on Windows..."
# Example output: "vda2" or "nvme0n1p2"
exfat_partition_device_name_short=$(lsblk -o name,label | grep wos-drive | awk '{print $1}' | grep -o -P '[a-z]+.*')
exfat_partition_device_name_full="/dev/${exfat_partition_device_name_short}"
# Example output: 2
exfat_partition_number=$(echo ${exfat_partition_device_name_short} | grep -o -P "[0-9]+$")

echo ${exfat_partition_device_name_short} | grep -q nvme
if [ $? -eq 0 ]; then
    # Example output: /dev/nvme0n1
    root_device=$(echo "${exfat_partition_device_name_full}" | grep -P -o "/dev/nvme[0-9]+n[0-9]+")
else
    # Example output: /dev/vda
    root_device=$(echo "${exfat_partition_device_name_full}" | sed s'/[0-9]//'g)
fi
parted ${root_device} set ${exfat_partition_number} msftdata on
echo "Upgrading exFAT partition to work on Windows complete."

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades complete."

echo "VERSION_ORIGNIAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
echo "End time: $(date --iso-8601=seconds)"
