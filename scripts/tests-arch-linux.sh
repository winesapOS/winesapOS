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

echo "Testing /etc/fstab mounts..."

echo "Checking that each mount exists in /etc/fstab..."
for i in \
  "^UUID=.*\s+/\s+btrfs\s+rw,noatime,nodiratime,space_cache,subvolid=.+,subvol=/\s+0\s+0" \
  "^UUID=.*\s+/home\s+btrfs\s+rw,noatime,nodiratime,space_cache,subvolid=.+,subvol=/home\s+0\s+0" \
  "UUID=.*\s+/boot/efi\s+vfat\s+rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro\s+0\s+2" \
  "none\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "none\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "none\s+/var/tmp\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "/swap\s+none\s+swap\s+defaults\s+0\s+0"
    do echo -n "\t${i}..."
    grep -q -P "${i}" /mnt/etc/fstab
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing /etc/fstab mounts complete.\n\n"

echo "Testing Btrfs subvolumes..."

echo "Checking that the Btrfs subvolumes exist..."
for i in \
  ".snapshots" \
  "home"
    do echo -n "\t${i}..."
    btrfs subvolume list /mnt | grep -q -P " ${i}$"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing Btrfs subvolumes complete.\n\n"

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

echo "Testing package installations..."

function pacman_search() {
    manjaro-chroot /mnt pacman -Qeq ${1} &> /dev/null
}

function pacman_search_loop() {
    for i in ${@}
        do echo -n "\t${i}..."
        pacman_search "${i}"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    done
}

echo "Checking that the base system packages are installed..."
pacman_search_loop btrfs-progs efibootmgr grub linux510 mkinitcpio networkmanager

echo "Checking that gaming system packages are installed..."
pacman_search_loop gamemode lib32-gamemode lutris steam wine-staging

echo "Checking that the Cinnamon desktop environment packages are installed..."
pacman_search_loop blueberry cinnamon lightdm xorg-server

echo -n "Testing package installations complete.\n\n"

echo "Testing Mac drivers installation..."

for i in \
  /mnt/usr/lib/modules/*/kernel/drivers/input/keyboard/applespi.ko.xz \
  /mnt/usr/lib/modules/*/kernel/drivers/spi/applespi.ko.xz \
  /mnt/usr/lib/modules/*/updates/apple-bce.ko.xz \
  /mnt/usr/lib/modules/*/updates/snd-hda-codec-cirrus.ko
    do echo -n "\t${i}..."
    ls "${i}" &> /dev/null
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing Mac drivers installation complete.\n\n"

echo "Testing that all files have been copied over..."

for i in \
  /mnt/etc/systemd/system/pacman-mirrors.service \
  /mnt/etc/systemd/system/touch-bar-usbmuxd-fix.service \
  /mnt/usr/local/bin/resize-root-file-system.sh \
  /mnt/etc/systemd/system/resize-root-file-system.service \
  /mnt/etc/snapper/configs/root \
  /mnt/etc/mac-linux-gaming-stick/VERSION \
  /mnt/etc/mac-linux-gaming-stick/install-manjaro.log
    do echo -n "\t${i}..."
    if [ -f ${i} ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing that all files have been copied over complete.\n\n"

echo "Testing that services are enabled..."

for i in \
  auto-cpufreq \
  lightdm \
  NetworkManager \
  pacman-mirrors \
  resize-root-file-system \
  snapper-cleanup.timer \
  snapper-timeline.timer \
  systemd-timesyncd \
  tlp \
  touch-bar-usbmuxd-fix
    do echo -n "\t${i}..."
    manjaro-chroot /mnt systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing that services are enabled complete.\n\n"

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
