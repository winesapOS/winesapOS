#!/bin/zsh

WINESAPOS_DEBUG_TESTS="${WINESAPOS_DEBUG_TESTS:-arch}"
if [[ "${WINESAPOS_DEBUG_TESTS}" == "true" ]]; then
    set -x
else
    set +x
fi

echo "Tests start time: $(date)"

DEVICE_SHORT="${WINESAPOS_DEVICE:-vda}"
DEVICE_FULL="/dev/${DEVICE_SHORT}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-steamos}"
WINESAPOS_DE="${WINESAPOS_DE:-plasma}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
# Required to change the default behavior to Zsh to fail and exit
# if a '*' glob is not found.
# https://github.com/LukeShortCloud/winesapOS/issues/137
setopt +o nomatch

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
  "^LABEL=.*\s+/\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard" \
  "^LABEL=.*\s+/home\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
  "^LABEL=.*\s+/swap\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
  "^(none|ramfs)\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^(none|ramfs)\s+/var/log\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^(none|ramfs)\s+/var/tmp\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^/swap/swapfile\s+none\s+swap\s+defaults\s+0\s+0"
    do echo -n "\t${i}..."
    grep -q -P "${i}" /mnt/etc/fstab
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    fstab_efi="^LABEL=.*\s+/efi\s+vfat\s+rw"
else
    fstab_efi="^LABEL=.*\s+/boot/efi\s+vfat\s+rw"
fi
echo -n "\t${i}..."
grep -q -P "${fstab_efi}" /mnt/etc/fstab
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
    arch-chroot /mnt pacman -Qsq ${1} &> /dev/null
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
pacman_search_loop efibootmgr grub mkinitcpio networkmanager

echo "Checking that the Linux kernel packages are installed..."
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop linux510 linux510-headers linux515 linux515-headers linux-firmware
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    pacman_search_loop linux-lts linux-lts-headers linux-firmware
elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    pacman_search_loop linux-lts linux-lts-headers linux-firmware linux-neptune linux-neptune-headers
fi

echo "Checking that gaming system packages are installed..."
pacman_search_loop discord-canary gamemode lib32-gamemode gamescope goverlay lutris mangohud lib32-mangohud wine-staging zerotier-one zerotier-gui-git

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop steam-manjaro steam-native
else
    pacman_search_loop steam steam-native-runtime
fi

echo "Checking that the Cinnamon desktop environment packages are installed..."
if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    pacman_search_loop cinnamon lightdm xorg-server
    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        pacman_search_loop \
            cinnamon-sounds \
            cinnamon-wallpapers \
            manjaro-cinnamon-settings \
            manjaro-settings-manager$ \
            adapta-maia-theme \
            kvantum-manjaro
    fi
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    pacman_search_loop plasma-meta plasma-nm
    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        pacman_search_loop \
            manjaro-kde-settings \
            manjaro-settings-manager-kcm \
            manjaro-settings-manager-knotifier \
            breath-classic-icon-themes \
            breath-wallpapers \
            plasma5-themes-breath \
            sddm-breath-theme
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        pacman_search steamdeck-kde-presets
    fi
fi

echo "Checking that Bluetooth packages are installed..."
pacman_search_loop bluez bluez-utils blueman bluez-qt
echo "Checking that Bluetooth packages are installed complete."

echo -n "Checking that the 'bluetooth' service is enabled..."
arch-chroot /mnt systemctl --quiet is-enabled bluetooth.service
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing package installations complete.\n\n"

echo "Testing Mac drivers installation..."

for i in \
  /mnt/usr/lib/modules/*/updates/dkms/apple-bce.ko* \
  /mnt/usr/lib/modules/*/updates/dkms/apple-ib-tb.ko* \
  /mnt/usr/lib/modules/*/updates/dkms/applespi.ko* \
  /mnt/usr/lib/modules/*/updates/snd-hda-codec-cirrus.ko* \
  /mnt/usr/lib/modules/5.15*/updates/snd-hda-codec-cs8409.ko*
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
  cups \
  lightdm \
  NetworkManager \
  resize-root-file-system \
  snapper-cleanup.timer \
  snapper-timeline.timer \
  systemd-timesyncd \
  touch-bar-usbmuxd-fix \
  zerotier-one
    do echo -n "\t${i}..."
    arch-chroot /mnt systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    i="pacman-mirrors"
    echo -n "\t${i}..."
    arch-chroot /mnt systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    i="reflector.service"
    echo -n "\t${i}..."
    arch-chroot /mnt systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

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

echo -n "Checking that GRUB is configured to save the default kernel..."
grep savedefault /mnt/boot/grub/grub.cfg | grep -v "function savedefault" | grep -q savedefault
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Checking that GRUB has command line arguments for faster input device polling..."
for i in usbhid.jspoll=1 usbhid.kbpoll=1 usbhid.mousepoll=1
    do echo -n "\t${i}..."
    grep -q "${i}" /mnt/boot/grub/grub.cfg
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Checking that GRUB has command line arguments for faster input device polling complete."

echo "Checking that GRUB has the command line argument for the 'none' I/O scheduler..."
grep -q "elevator=none" /mnt/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Checking that GRUB has the command line argument for the 'none' I/O scheduler complete."

if [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    echo -n "Checking that GRUB will correctly default to newer kernels on Arch Linux..."
    grep -q 'linux=`version_find_latest $list`' /mnt/etc/grub.d/10_linux
    if [ $? -eq 0 ]; then
        echo FAIL
    else
        echo PASS
    fi
    echo "Checking that GRUB will correctly default to newer kernels on Arch Linux complete."
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
  /mnt/home/winesap/Desktop/multimc.desktop \
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
  /mnt/home/winesap/Desktop/blueman-manager.desktop \
  /mnt/home/winesap/Desktop/org.gnome.Cheese.desktop \
  /mnt/home/winesap/Desktop/clamtk.desktop \
  /mnt/home/winesap/Desktop/discord-canary.desktop \
  /mnt/home/winesap/Desktop/firefox-esr.desktop \
  /mnt/home/winesap/Desktop/google-chrome.desktop \
  /mnt/home/winesap/Desktop/io.github.benjamimgois.goverlay.desktop \
  /mnt/usr/share/applications/org.keepassxc.KeePassXC.desktop \
  /mnt/home/winesap/Desktop/libreoffice-startcenter.desktop \
  /mnt/home/winesap/Desktop/ludusavi.desktop \
  /mnt/home/winesap/Desktop/org.manjaro.pamac.manager.desktop \
  /mnt/home/winesap/Desktop/qdirstat.desktop \
  /mnt/home/winesap/Desktop/shutter.desktop \
  /mnt/home/winesap/Desktop/terminator.desktop \
  /mnt/home/winesap/Desktop/transmission-qt.desktop \
  /mnt/home/winesap/Desktop/veracrypt.desktop \
  /mnt/home/winesap/Desktop/vlc.desktop \
  /mnt/home/winesap/Desktop/zerotier-gui.desktop \
  /mnt/home/winesap/Desktop/README.txt
    do echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
      echo PASS
    else
      echo FAIL
    fi
done

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    i="/mnt/home/winesap/Desktop/firewall-config.desktop"
    echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    i=/mnt/home/winesap/Desktop/nemo.desktop
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    i=/mnt/home/winesap/Desktop/org.kde.dolphin.desktop
fi
echo -n "\tChecking if the file ${i} exists..."
if [ -f "${i}" ]; then
    echo PASS
else
    echo FAIL
fi
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

echo -n "\tChecking that the Proton tarball has been removed..."
ls -1 /mnt/home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -q -P ".tar.gz$"
if [ $? -eq 1 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Proton GE has been installed complete."

echo -n "Testing that Oh My Zsh is installed..."
if [ -f /mnt/home/winesap/.zshrc ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Oh My Zsh is installed complete."

echo -n "Testing that the mkinitcpio hooks are loaded in the correct order..."
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    grep -q "HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)" /mnt/etc/mkinitcpio.conf
    hooks_result="$?"
else
    grep -q "HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)" /mnt/etc/mkinitcpio.conf
    hooks_result="$?"
fi
if [ "${hooks_result}" -eq 0 ]; then
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
        grep -q "IgnorePkg = linux515 linux515-headers linux510 linux510-headers" /mnt/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-lts510 linux-lts510-headers" /mnt/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-lts510 linux-lts510-headers linux-neptune linux-neptune-headers" /mnt/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi
fi

echo -n 'Checking that the locale has been set to "en_US.UTF-8 UTF-8"...'
arch-chroot /mnt locale | grep -q "LANG=en_US.UTF-8"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Checking that all the packages from the AUR have been installed by yay..."
pacman_search_loop \
    auto-cpufreq \
    cloud-guest-utils \
    crudini \
    firefox-esr-bin \
    google-chrome \
    heroic-games-launcher-bin \
    hfsprogs \
    macbook12-spi-driver-dkms \
    multimc-bin \
    protontricks \
    python-iniparse \
    qdirstat
if [[ "${WINESAPOS_DISTRO}" != "manjaro" ]]; then
    pacman_search_loop \
        lightdm-settings \
        oh-my-zsh-git
    if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
        pacman_search krathalans-apparmor-profiles-git
    fi
fi
echo "Checking that all the packages from the AUR have been installed by yay done."

echo 'Testing that the "pamac" package manager is installed...'
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop \
      pamac-gtk pamac-cli \
      libpamac-flatpak-plugin \
      libpamac-snap-plugin
else
    pacman_search_loop \
      pamac-all
fi

echo 'Testing that the "pamac" package manager is installed complete.'

echo 'Testing that the PipeWire audio library is installed...'
echo "Checking that PipeWire packages are installed..."
pacman_search_loop \
  pavucontrol \
  pipewire \
  lib32-pipewire \
  pipewire-media-session \
  pipewire-alsa \
  pipewire-jack \
  lib32-pipewire-jack \
  pipewire-pulse \
  pipewire-v4l2 \
  lib32-pipewire-v4l2
echo "Checking that PipeWire packages are installed complete."

echo "Checking that PipeWire services are enabled..."
for i in \
  mute.service \
  pipewire.service \
  pipewire-pulse.service
    do echo -n "\t${i}..."
    ls "/mnt/home/winesap/.config/systemd/user/default.target.wants/${i}" &> /dev/null
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Checking that PipeWire services are enabled complete."
echo 'Testing that the PipeWire audio library is installed complete.'

echo 'Testing that support for all file systems is installed...'
pacman_search_loop \
  apfsprogs-git \
  btrfs-progs \
  dosfstools \
  e2fsprogs \
  exfatprogs \
  hfsprogs \
  linux-apfs-rw-dkms-git \
  ntfs-3g \
  xfsprogs \
  zfs-dkms \
  zfs-utils

echo -n "Checking for the existence of '/etc/modules-load.d/winesapos-file-systems.conf'..."
ls /mnt/etc/modules-load.d/winesapos-file-systems.conf &> /dev/null
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo 'Testing that support for all file systems is installed complete.'

echo -n "Checking that the correct operating system was installed..."
grep -q "ID=${WINESAPOS_DISTRO}" /mnt/etc/os-release
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Tests end time: $(date)"
