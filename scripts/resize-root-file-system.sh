#!/bin/bash

root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')
root_partition_number=$(echo ${root_partition} | grep -o -P "[0-9]+")
root_device=$(echo ${root_partition} | sed s'/[0-9]//'g)
growpart ${root_device} ${root_partition_number}
btrfs filesystem resize max /
