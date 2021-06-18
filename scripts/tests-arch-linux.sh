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

echo -n "Testing partitions complete.\n\n"

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

echo -n "Testing swap complete.\n\n"

echo "Testing user creation..."

echo -n "Checking that the 'stick' user exists..."
grep -P -q "^stick:" /mnt/etc/passwd
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the home directory for the 'stick' user exists..."
if [ -d /mnt/home/stick/ ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing user creation complete.\n\n"

echo "Testing the bootloader..."

echo -n "Checking that GRUB 2 has been installed..."
pacman -S --noconfirm binutils > /dev/null
dd if=${DEVICE_FULL} bs=512 count=1 2> /dev/null | strings | grep -q GRUB
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the '/boot/grub/grub.cfg' file exists..."
if [ -f /mnt/boot/grub/grub.cfg ]; then
    echo PASS
else
    echo FAIL
fi

echo -n " Checking that the generic '/boot/efi/EFI/BOOT/BOOTX64.EFI' file exists..."
if [ -f /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB terminal is set to 'console'..."
grep -q "terminal_input console" /mnt/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB timeout has been set to 5 seconds..."
grep -q "set timeout=5" /mnt/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Testing the bootloader complete."
