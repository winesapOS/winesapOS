#!/bin/bash

set -x

# The amount of space, in GiB, to reserve at the end of the storage device for an exFAT partition
# that is used for cross-platform storage between Linux, macOS, and Windows. A value of "0" means
# that no space is reserved and the root partition is grown to fill the entire storage device.
#
# Passing "--print-max-exfat-size" instead prints the largest size that can be requested and then
# exits without making any changes. The winesapOS first-time setup uses this to build and validate
# the size that a user selects.
exfat_size_gib="${1:-0}"

# Always leave the root partition at least this much space, in GiB, to grow into. Otherwise a user
# could reserve every last byte for the exFAT partition and leave no room for their games.
exfat_root_growth_min_gib=2

# exFAT file systems require labels that are 11 characters or shorter.
exfat_label="wos-drive"

# Determine which storage device a partition belongs to.
# Example input: "/dev/nvme0n1p5". Example output: "/dev/nvme0n1".
partition_to_device() {
    if echo "${1}" | grep -q nvme; then
        # Example output: /dev/nvme0n1
        echo "${1}" | grep -P -o "/dev/nvme[0-9]+n[0-9]+"
    elif echo "${1}" | grep -q mmcblk; then
        # Example output: /dev/mmcblk0
        echo "${1}" | grep -P -o "/dev/mmcblk[0-9]+"
    elif echo "${1}" | grep -q loop; then
        # Example output: /dev/loop0
        echo "${1}" | grep -P -o "/dev/loop[0-9]+"
    else
        # Example output: /dev/sda
        # shellcheck disable=SC2001 disable=SC2026
        echo "${1}" | sed s'/[0-9]//'g
    fi
}

# Build the path to a partition on a storage device.
# Example input: "/dev/nvme0n1" and "5". Example output: "/dev/nvme0n1p5".
device_partition_path() {
    if echo "${1}" | grep -q -P "^/dev/(nvme|loop|mmcblk)"; then
        # "nvme", "loop", and "mmcblk" devices separate the device name and partition number
        # by using a "p".
        echo "${1}p${2}"
    else
        echo "${1}${2}"
    fi
}

# Example output: "/dev/mmcblk0p5" (SD card or eMMC), "/dev/nvme0n1p5" (NVMe), or "/dev/sda5" (SATA)
root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')

if [[ "${root_partition}" == "/dev/mapper/cryptroot" ]]; then
    # Example output: "mmcblk0p5", "nvme0n1p5", "sda5"
    root_partition_shortname=$(lsblk -o name,label | grep winesapos-luks | awk '{print $1}' | grep -o -P '[a-z]+.*')
else
    # Example output: "sda5"
    root_partition_shortname=$(basename "${root_partition}")
fi

# Example output: 5
root_partition_number=$(echo "${root_partition_shortname}" | grep -o -P "[0-9]+$")
# Example output: /dev/sda
root_device=$(partition_to_device "/dev/${root_partition_shortname}")

# The kernel reports all of these sizes in 512 byte sectors. There are 2048 sectors in a MiB.
# These are read from "/sys" instead of 'parted' because the backup GPT header is not yet at the end
# of the storage device, which makes 'parted' refuse to print anything without being fixed first.
device_size_mib=$(($(cat "/sys/class/block/$(basename "${root_device}")/size") / 2048))
root_partition_start_mib=$(($(cat "/sys/class/block/${root_partition_shortname}/start") / 2048))
root_partition_size_mib=$(($(cat "/sys/class/block/${root_partition_shortname}/size") / 2048))
root_partition_end_mib=$((root_partition_start_mib + root_partition_size_mib))

# The amount of unallocated space at the end of the storage device.
free_mib=$((device_size_mib - root_partition_end_mib))
# Reserve 1 MiB at the end of the storage device for the backup GPT header and partition alignment.
exfat_size_max_gib=$(((free_mib - (exfat_root_growth_min_gib * 1024) - 1) / 1024))
if [[ "${exfat_size_max_gib}" -lt 0 ]]; then
    exfat_size_max_gib=0
fi

# An exFAT partition cannot be created on a MBR partition table because winesapOS already uses all
# four of the primary partitions that MBR supports.
if [[ "$(lsblk --nodeps --noheadings --output PTTYPE "${root_device}")" != "gpt" ]]; then
    exfat_size_max_gib=0
fi

# Do not create a second exFAT partition if one already exists. This happens when the first-time
# setup is manually ran again after it has already completed.
if lsblk --noheadings --output LABEL | grep -q -P "^${exfat_label}$"; then
    exfat_size_max_gib=0
fi

if [[ "${exfat_size_gib}" == "--print-max-exfat-size" ]]; then
    echo "${exfat_size_max_gib}"
    exit 0
fi

if ! echo "${exfat_size_gib}" | grep -q -P "^[0-9]+$"; then
    echo "'${exfat_size_gib}' is not a valid size in GiB for the exFAT partition."
    exit 1
fi

if [[ "${exfat_size_gib}" -gt "${exfat_size_max_gib}" ]]; then
    echo "An exFAT partition of ${exfat_size_gib} GiB cannot be created because the maximum size is ${exfat_size_max_gib} GiB. Only the root partition will be grown."
    exfat_size_gib=0
fi

# The backup GPT header is at the end of the winesapOS image, not at the end of the storage device
# that the image was copied onto. Relocate it so that the rest of the storage device is usable.
if [[ "$(lsblk --nodeps --noheadings --output PTTYPE "${root_device}")" == "gpt" ]]; then
    sgdisk --move-second-header "${root_device}"
    sync
    partprobe "${root_device}"
    udevadm settle
fi

if [[ "${exfat_size_gib}" == "0" ]]; then
    root_partition_end_new="100%"
else
    root_partition_end_new="$((device_size_mib - (exfat_size_gib * 1024) - 1))MiB"
fi

# 'parted' refuses to resize a partition that is in-use unless the warning is answered
# interactively. The root partition is always in-use so pretend that a terminal is attached.
# Only the end of the root partition moves, and only into unallocated space, so no data is moved.
parted ---pretend-input-tty "${root_device}" unit MiB resizepart "${root_partition_number}" "${root_partition_end_new}" <<< "Yes"
sync
partprobe "${root_device}"
udevadm settle

if [[ "${exfat_size_gib}" != "0" ]]; then
    exfat_partition_number=$((root_partition_number + 1))
    exfat_partition=$(device_partition_path "${root_device}" "${exfat_partition_number}")
    # The exFAT partition starts exactly where the root partition now ends.
    parted --script "${root_device}" unit MiB mkpart primary "${root_partition_end_new}" 100%
    ## Configure this partition to be automatically mounted on Windows.
    parted --script "${root_device}" set "${exfat_partition_number}" msftdata on
    # Avoid a race-condition where formatting the device may happen before the system detects the
    # new partition.
    sync
    partprobe "${root_device}"
    udevadm settle
    mkfs -t exfat "${exfat_partition}"
    exfatlabel "${exfat_partition}" "${exfat_label}"
fi

if [[ "${root_partition}" == "/dev/mapper/cryptroot" ]]; then
    # This only works before the first-time setup has changed the LUKS encryption password.
    echo "password" | cryptsetup resize "${root_partition}"
fi

btrfs filesystem resize max /
