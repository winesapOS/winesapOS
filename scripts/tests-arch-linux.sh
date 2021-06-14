#!/bin/zsh

DEVICE_SHORT=vda
DEVICE_FULL="/dev/${DEVICE_SHORT}"

echo "Testing partitions..."
lsblk_f_output=$(lsblk -f)

echo -n "Checking that ${DEVICE_FULL}1 is not formatted..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}1     "
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}2 is formatted as FAT32..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}2 vfat"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}3 is formatted as Btrfs..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}3 btrfs"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Testing partitions complete."

echo "Testing swap..."

echo -n "Checking that the swap file exists..."
if [ -f /mnt/swap ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has copy-on-write disabled..."
lsattr /mnt/swap | grep -q "C------ /mnt/swap"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has the correct permissions..."
swap_file_perms=$(ls -l /mnt | grep -P " swap$" | awk '{print $1}')
if [[ "${swap_file_perms}" == "-rw-------" ]]; then
    echo PASS
else
    echo FAIL
fi

echo "Testing swap complete."
