#!/bin/bash

set -x

root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')

if [[ "${root_partition}" == "/dev/mapper/cryptroot" ]]; then
    # Example output: vda5
    root_partition_shortname=$(lsblk -o name,label | grep mlgs-luks | awk '{print $1}' | grep -o -P '[a-z]+.*')
    # Example output: 5
    root_partition_number=$(echo ${root_partition_shortname} | grep -o -P "[0-9]+")
    # Example output: /dev/vda
    root_device=$(echo "/dev/${root_partition_shortname}" | sed s'/[0-9]//'g)
    growpart ${root_device} ${root_partition_number}
    echo "password" | cryptsetup resize ${root_partition}
else
    root_partition_number=$(echo ${root_partition} | grep -o -P "[0-9]+")
    root_device=$(echo ${root_partition} | sed s'/[0-9]//'g)
    growpart ${root_device} ${root_partition_number}
fi

btrfs filesystem resize max /
