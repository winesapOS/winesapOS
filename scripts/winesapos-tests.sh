#!/bin/zsh

if [[ "${WINESAPOS_DEBUG}" == "true" ]]; then
    set -x
fi

echo "Tests start time: $(date)"

DEVICE_SHORT="${WINESAPOS_DEVICE:-vda}"
DEVICE_FULL="/dev/${DEVICE_SHORT}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-arch}"

echo "Testing partitions..."
lsblk_f_output=$(lsblk -f)

echo -n "Checking that ${DEVICE_FULL}1 is not formatted..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}1     "
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}2 is formatted as exFAT..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}2.*exfat"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}3 is formatted as FAT32..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}3.*vfat"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}4 is formatted as ext4..."
echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}4.*ext4"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that ${DEVICE_FULL}5 is formatted as Btrfs..."
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    echo ${lsblk_f_output} | grep -q "cryptroot btrfs"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
else
    echo ${lsblk_f_output} | grep -q "${DEVICE_SHORT}5 btrfs"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

echo -n "Testing partitions complete.\n\n"

echo "Testing swap..."

echo -n "Checking that the swap file exists..."
if [ -f /mnt/swap/swapfile ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has copy-on-write disabled..."
lsattr /mnt/swap/swapfile | grep -q "C------ /mnt/swap/swapfile"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has the correct permissions..."
swap_file_perms=$(ls -l /mnt/swap | grep -P " swapfile$" | awk '{print $1}')
if [[ "${swap_file_perms}" == "-rw-------" ]]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing swap complete.\n\n"

echo "Testing /etc/fstab mounts..."

echo "Checking that each mount exists in /etc/fstab..."
for i in \
  "^LABEL=.*\s+/\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard,space_cache,subvolid=.+,subvol=/\s+0\s+0" \
  "^LABEL=.*\s+/home\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard,space_cache,subvolid=.+,subvol=/home\s+0\s+0" \
  "^LABEL=.*\s+/swap\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard,space_cache,subvolid=.+,subvol=/swap\s+0\s+0" \
  "^LABEL=.*\s+/boot/efi\s+vfat\s+rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro\s+0\s+2" \
  "^none\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^none\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^none\s+/var/tmp\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^/swap/swapfile\s+none\s+swap\s+defaults\s+0\s+0"
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
  "home" \
  "home/\.snapshots" \
  "swap"
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

echo -n "Checking that the 'winesap' user exists..."
grep -P -q "^winesap:" /mnt/etc/passwd
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the home directory for the 'winesap' user exists..."
if [ -d /mnt/home/winesap/ ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing user creation complete.\n\n"

echo "Testing package installations..."

function pacman_search() {
    arch-chroot /mnt pacman -Qeq ${1} &> /dev/null
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
pacman_search_loop btrfs-progs efibootmgr grub mkinitcpio networkmanager

echo "Checking that the Linux kernel packages are installed..."
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop linux54 linux54-headers linux510 linux510-headers
else
    pacman_search_loop linux-lts linux-lts-headers linux-lts54 linux-lts54-headers
fi

echo "Checking that gaming system packages are installed..."
pacman_search_loop gamemode lib32-gamemode lutris wine-staging

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop steam-manjaro steam-native
else
    pacman_search_loop steam steam-native-runtime
fi

echo "Checking that the Cinnamon desktop environment packages are installed..."
pacman_search_loop blueberry cinnamon lightdm xorg-server

echo -n "Testing package installations complete.\n\n"

echo "Testing Mac drivers installation..."

for i in \
  /mnt/usr/lib/modules/*/updates/dkms/apple-bce.ko.xz \
  /mnt/usr/lib/modules/*/updates/dkms/apple-ib-tb.ko.xz \
  /mnt/usr/lib/modules/*/updates/dkms/applespi.ko.xz \
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
  /mnt/etc/winesapos/VERSION \
  /mnt/etc/winesapos/winesapos-install.log
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
    arch-chroot /mnt systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo -n "\tapparmor..."
    arch-chroot /mnt systemctl --quiet is-enabled apparmor
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

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

echo -n "Checking that the GRUB timeout has been set to 10 seconds..."
grep -q "set timeout=10" /mnt/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB timeout style been set to 'menu'..."
grep -q "set timeout_style=menu" /mnt/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Testing the bootloader complete."

echo -n "Testing that 'yay' is installed..."
if [ -f /mnt/usr/bin/yay ]; then
    echo PASS
else
    echo FAIL
fi

echo "Testing desktop shortcuts..."
for i in \
  /mnt/home/winesap/Desktop/heroic_games_launcher.desktop \
  /mnt/home/winesap/Desktop/lutris.desktop \
  /mnt/home/winesap/Desktop/steam_native.desktop \
  /mnt/home/winesap/Desktop/steam_runtime.desktop
    do echo -n "\tChecking if gamemoderun is configured for file ${i}..."
    grep -q -P "^Exec=/usr/bin/gamemoderun " "${i}"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

for i in \
  /mnt/home/winesap/Desktop/freeoffice-planmaker.desktop \
  /mnt/home/winesap/Desktop/freeoffice-presentations.desktop \
  /mnt/home/winesap/Desktop/freeoffice-presentations.desktop \
  /mnt/home/winesap/Desktop/google-chrome.desktop \
  /mnt/home/winesap/Desktop/qdirstat.desktop
    do echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
      echo PASS
    else
      echo FAIL
    fi
done
echo "Testing desktop shortcuts complete."

echo "Testing that Proton GE has been installed..."
echo -n "\tChecking that the 'ge-install-manager' script is present..."
if [ -f /mnt/usr/local/bin/ge-install-manager ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "\tChecking that Proton GE is installed..."
ls -1 /mnt/home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^Proton.*GE.*"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Proton GE has been installed complete."

echo "Testing that the PulseAudio file exists..."
if [ -f /mnt/home/winesap/.config/pulse/default.pa ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the PulseAudio file exists complete."

echo -n "Testing printer driver services..."
if [ -f /mnt/etc/systemd/system/printer.target.wants/cups.service ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing printer driver services complete."

echo -n "Testing that Oh My Zsh is installed..."
if [ -f /mnt/home/winesap/.zshrc ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Oh My Zsh is installed complete."

echo -n "Testing that the mkinitcpio hooks are loaded in the correct order..."
grep -q "HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)" /mnt/etc/mkinitcpio.conf
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the mkinitcpio hooks are loaded in the correct order complete."

echo -n "Testing that ParallelDownloads is enabled in Pacman..."
grep -q -P "^ParallelDownloads" /mnt/etc/pacman.conf
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that ParallelDownloads is enabled in Pacman complete."

echo "Testing that the machine-id was reset..."
echo -n "\tChecking that the /etc/machine-id file is empty..."
if [[ "$(cat /mnt/etc/machine-id)" == "" ]]; then
    echo PASS
else
    echo FAIL
fi
echo -n "\tChecking that /var/lib/dbus/machine-id is a symlink..."
if [[ -L /mnt/var/lib/dbus/machine-id ]]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the machine-id was reset complete."

echo -n "\tTesting that the offline ClamAV database was downloaded..."
if [[ -f /mnt/var/lib/clamav/main.cvd ]]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the offline ClamAV database was downloaded complete."

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    echo -n "Testing that the firewall has been installed..."
    if [[ -f /mnt/usr/bin/firewalld ]]; then
        echo PASS
    else
        echo FAIL
    fi
fi

WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
if [[ "${WINESAPOS_CPU_MITIGATIONS}" == "false" ]]; then
    echo -n "Testing that CPU mitigations are disabled in the Linux kernel..."
    grep -q "mitigations=off" /mnt/etc/default/grub
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

WINESAPOS_DISABLE_KERNEL_UPDATES="${WINESAPOS_DISABLE_KERNEL_UPDATES:-true}"
if [[ "${WINESAPOS_DISABLE_KERNEL_UPDATES}" == "true" ]]; then
    echo -n "Testing that Pacman is configured to disable Linux kernel updates..."
    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        grep -q "IgnorePkg = linux510 linux510-headers linux54 linux54-headers" /mnt/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    else
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-lts54 linux-lts54-headers" /mnt/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi
fi

echo "Tests end time: $(date)"
