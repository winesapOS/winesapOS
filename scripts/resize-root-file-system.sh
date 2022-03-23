#!/bin/bash

set -x

# Example output: "/dev/vda5" or "/dev/nvme0n1p5"
root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')

if [[ "${root_partition}" == "/dev/mapper/cryptroot" ]]; then
    # Example output: "vda5" or "nvme0n1p5"
    root_partition_shortname=$(lsblk -o name,label | grep winesapos-luks | awk '{print $1}' | grep -o -P '[a-z]+.*')
    # Example output: 5
    root_partition_number=$(echo ${root_partition_shortname} | grep -o -P "[0-9]+$")

    echo ${root_partition} | grep -q nvme
    if [ $? -eq 0 ]; then
        # Example output: /dev/nvme0n1
        root_device=$(echo "/dev/${root_partition_shortname}" | grep -P -o "/dev/nvme[0-9]+n[0-9]+")
    else
        # Example output: /dev/vda
        root_device=$(echo "/dev/${root_partition_shortname}" | sed s'/[0-9]//'g)
    fi

    growpart ${root_device} ${root_partition_number}
    echo "password" | cryptsetup resize ${root_partition}
else
    root_partition_number=$(echo ${root_partition} | grep -o -P "[0-9]+$")

    echo ${root_partition} | grep -q nvme
    if [ $? -eq 0 ]; then
        root_device=$(echo ${root_partition} | grep -P -o "/dev/nvme[0-9]+n[0-9]+")
    else
        root_device=$(echo ${root_partition} | sed s'/[0-9]//'g)
    fi

    growpart ${root_device} ${root_partition_number}
fi

btrfs filesystem resize max /
