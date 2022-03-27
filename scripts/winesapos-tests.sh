#!/bin/zsh

WINESAPOS_DEBUG_TESTS="${WINESAPOS_DEBUG_TESTS:-false}"
if [[ "${WINESAPOS_DEBUG_TESTS}" == "true" ]]; then
    set -x
else
    set +x
fi

echo "Tests start time: $(date)"

WINESAPOS_INSTALL_DIR="${WINESAPOS_INSTALL_DIR:-/winesapos}"
DEVICE_SHORT="${WINESAPOS_DEVICE:-vda}"
DEVICE_FULL="/dev/${DEVICE_SHORT}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-steamos}"
WINESAPOS_DE="${WINESAPOS_DE:-plasma}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
WINESAPOS_SUDO_NO_PASSWORD="${WINESAPOS_SUDO_NO_PASSWORD:-true}"
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

echo -n "Checking that ${DEVICE_FULL}2 has the 'msftdata' partition flag..."
parted ${DEVICE_FULL} print | grep -q msftdata
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
if [ -f ${WINESAPOS_INSTALL_DIR}/swap/swapfile ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has copy-on-write disabled..."
lsattr ${WINESAPOS_INSTALL_DIR}/swap/swapfile | grep -q "C------ ${WINESAPOS_INSTALL_DIR}/swap/swapfile"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the swap file has the correct permissions..."
swap_file_perms=$(ls -l ${WINESAPOS_INSTALL_DIR}/swap | grep -P " swapfile$" | awk '{print $1}')
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
  "^(none|ramfs)\s+/var/tmp\s+ramfs\s+rw,nosuid,nodev\s+0\s+0" \
  "^/swap/swapfile\s+none\s+swap\s+defaults\s+0\s+0"
    do echo -n "\t${i}..."
    grep -q -P "${i}" ${WINESAPOS_INSTALL_DIR}/etc/fstab
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    fstab_efi="^LABEL=.*\s+/efi\s+vfat\s+rw"
else
    fstab_efi="^LABEL=.*\s+/boot/efi\s+vfat\s+rw"
fi
echo -n "\t${fstab_efi}..."
grep -q -P "${fstab_efi}" ${WINESAPOS_INSTALL_DIR}/etc/fstab
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo -n "Testing /etc/fstab mounts complete.\n\n"

echo "Testing Btrfs subvolumes..."

echo "Checking that the Btrfs subvolumes exist..."
for i in \
  ".snapshots" \
  "home" \
  "home/\.snapshots" \
  "swap"
    do echo -n "\t${i}..."
    btrfs subvolume list ${WINESAPOS_INSTALL_DIR} | grep -q -P " ${i}$"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

echo -n "Testing Btrfs subvolumes complete.\n\n"

echo "Testing user creation..."

echo -n "Checking that the 'winesap' user exists..."
grep -P -q "^winesap:" ${WINESAPOS_INSTALL_DIR}/etc/passwd
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the home directory for the 'winesap' user exists..."
if [ -d ${WINESAPOS_INSTALL_DIR}/home/winesap/ ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing user creation complete.\n\n"

echo "Testing package installations..."

function pacman_search() {
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman -Qsq ${1} &> /dev/null
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
pacman_search_loop \
  efibootmgr \
  grub \
  mkinitcpio \
  networkmanager \
  inetutils

echo "Checking that the Linux kernel packages are installed..."
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop linux510 linux510-headers linux515 linux515-headers linux-firmware
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    pacman_search_loop linux-lts linux-lts-headers linux-firmware
elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    pacman_search_loop linux-lts linux-lts-headers linux-firmware linux-neptune linux-neptune-headers
fi

echo "Checking that additional Linux firmware is installed..."
pacman_search_loop \
  linux-firmware-bnx2x \
  linux-firmware-liquidio \
  linux-firmware-marvell \
  linux-firmware-mellanox \
  linux-firmware-nfp \
  linux-firmware-qcom \
  linux-firmware-qlogic \
  linux-firmware-whence

echo "Checking that gaming system packages are installed..."
pacman_search_loop \
  bottles \
  discord-canary \
  gamemode \
  lib32-gamemode \
  gamescope \
  goverlay \
  lutris \
  mangohud \
  lib32-mangohud \
  obs-studio \
  protonup-qt \
  wine-ge-custom \
  zerotier-one \
  zerotier-gui-git

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman_search_loop steam-manjaro steam-native
else
    pacman_search_loop steam steam-native-runtime
fi

echo "Checking that the desktop environment packages are installed..."
pacman_search_loop \
  xorg-server \
  lib32-mesa \
  mesa \
  xorg-server \
  xorg-xinit \
  xterm \
  xf86-input-libinput \
  xf86-video-amdgpu \
  xf86-video-intel \
  xf86-video-nouveau

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    pacman_search_loop \
      cinnamon \
      lightdm \
      xorg-server \
      pix
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
    pacman_search_loop \
      plasma-meta \
      plasma-nm \
      dolphin \
      ffmpegthumbs \
      kdegraphics-thumbnailers \
      konsole \
      gwenview \
      phonon-qt5-vlc
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
        pacman_search_loop steamdeck-kde-presets
    fi
fi

echo "Checking that Bluetooth packages are installed..."
pacman_search_loop bluez bluez-utils blueman bluez-qt
echo "Checking that Bluetooth packages are installed complete."

echo -n "Checking that the 'bluetooth' service is enabled..."
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled bluetooth.service
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Testing package installations complete.\n\n"

echo "Testing Mac drivers installation..."

for i in \
  ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/*/updates/dkms/apple-bce.ko* \
  ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/*/updates/dkms/apple-ib-tb.ko* \
  ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/*/updates/dkms/applespi.ko* \
  ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/*/updates/snd-hda-codec-cirrus.ko* \
  ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/5.15*/updates/snd-hda-codec-cs8409.ko*
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
  ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/winesapos-touch-bar-usbmuxd-fix.service \
  ${WINESAPOS_INSTALL_DIR}/usr/local/bin/winesapos-touch-bar-usbmuxd-fix.sh \
  ${WINESAPOS_INSTALL_DIR}/etc/systemd/user/winesapos-mute.service \
  ${WINESAPOS_INSTALL_DIR}/usr/local/bin/winesapos-mute.sh \
  ${WINESAPOS_INSTALL_DIR}/usr/local/bin/winesapos-resize-root-file-system.sh \
  ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/winesapos-resize-root-file-system.service \
  ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/root \
  ${WINESAPOS_INSTALL_DIR}/etc/winesapos/VERSION \
  ${WINESAPOS_INSTALL_DIR}/etc/winesapos/winesapos-install.log
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
  winesapos-resize-root-file-system \
  snapper-cleanup.timer \
  snapper-timeline.timer \
  systemd-timesyncd \
  winesapos-touch-bar-usbmuxd-fix \
  zerotier-one
    do echo -n "\t${i}..."
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    i="pacman-mirrors"
    echo -n "\t${i}..."
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    i="reflector.service"
    echo -n "\t${i}..."
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo -n "\tapparmor..."
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled apparmor
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
if [ -f ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg ]; then
    echo PASS
else
    echo FAIL
fi

echo -n " Checking that the generic '/boot/efi/EFI/BOOT/BOOTX64.EFI' file exists..."
if [ -f ${WINESAPOS_INSTALL_DIR}/boot/efi/EFI/BOOT/BOOTX64.EFI ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB terminal is set to 'console'..."
grep -q "terminal_input console" ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB timeout has been set to 10 seconds..."
grep -q "set timeout=10" ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the GRUB timeout style been set to 'menu'..."
grep -q "set timeout_style=menu" ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that GRUB is configured to save the default kernel..."
grep savedefault ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg | grep -v "function savedefault" | grep -q savedefault
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo "Checking that GRUB has command line arguments for faster input device polling..."
for i in usbhid.jspoll=1 usbhid.kbpoll=1 usbhid.mousepoll=1
    do echo -n "\t${i}..."
    grep -q "${i}" ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Checking that GRUB has command line arguments for faster input device polling complete."

echo "Checking that GRUB has the command line argument for the 'none' I/O scheduler..."
grep -q "elevator=none" ${WINESAPOS_INSTALL_DIR}/boot/grub/grub.cfg
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Checking that GRUB has the command line argument for the 'none' I/O scheduler complete."

if [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    echo -n "Checking that GRUB will correctly default to newer kernels on Arch Linux..."
    grep -q 'linux=`version_find_latest $list`' ${WINESAPOS_INSTALL_DIR}/etc/grub.d/10_linux
    if [ $? -eq 0 ]; then
        echo FAIL
    else
        echo PASS
    fi
    echo "Checking that GRUB will correctly default to newer kernels on Arch Linux complete."
fi

echo -n "Checking that the Steam Big Picture theme for GRUB exists..."
if [ -f ${WINESAPOS_INSTALL_DIR}/boot/grub/themes/SteamBP/theme.txt ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the Steam Big Picture theme for GRUB is enabled..."
grep -q -P "^GRUB_THEME=/boot/grub/themes/SteamBP/theme.txt" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that GRUB is set to use resolutions supported by our theme..."
grep -q -P "^GRUB_GFXMODE=1600x1200,1024x768,800x600,640x480,auto" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing the bootloader complete."

echo "Testing that 'yay' is installed..."
echo -n "Checking for the 'yay' binary..."
if [ -f ${WINESAPOS_INSTALL_DIR}/usr/bin/yay ]; then
    echo PASS
else
    echo FAIL
fi

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    echo "Checking that the 'yay-git' package is installed..."
    pacman_search_loop yay-git
    echo "Checking that the 'yay-git' package is installed complete."
fi
echo -n "Testing that 'yay' is complete..."

echo "Testing desktop shortcuts..."
for i in \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/multimc.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_deck_runtime.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_runtime.desktop
    do echo -n "\tChecking if gamemoderun is configured for file ${i}..."
    grep -q -P "^Exec=/usr/bin/gamemoderun " "${i}"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

for i in \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/blueman-manager.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.usebottles.bottles.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.gnome.Cheese.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/clamtk.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/discord-canary.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/balena-etcher-electron.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/firefox-esr.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/io.github.benjamimgois.goverlay.desktop \
  ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.keepassxc.KeePassXC.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/libreoffice-startcenter.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/ludusavi.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.obsproject.Studio.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.manjaro.pamac.manager.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/peazip.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/net.davidotek.pupgui2.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/qdirstat.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/shutter.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/terminator.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/transmission-qt.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/veracrypt.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/vlc.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/zerotier-gui.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/README.txt
    do echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
      echo PASS
    else
      echo FAIL
    fi
done

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    i="${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/firewall-config.desktop"
    echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    x=("${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/nemo.desktop" "${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/pix.desktop")
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    x=("${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.kde.dolphin.desktop" "${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.kde.gwenview.desktop")
fi

for y in $x;
    do echo -n "\tChecking if the file ${y} exists..."
    if [ -f "${y}" ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Testing desktop shortcuts complete."

echo "Testing that Proton GE has been installed..."
echo -n "\tChecking that Proton GE is installed..."
ls -1 ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^GE-Proton.*"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "\tChecking that the Proton tarball has been removed..."
ls -1 ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -q -P ".tar.gz$"
if [ $? -eq 1 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Proton GE has been installed complete."

echo -n "Testing that Oh My Zsh is installed..."
if [ -f ${WINESAPOS_INSTALL_DIR}/home/winesap/.zshrc ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that Oh My Zsh is installed complete."

echo -n "Testing that the mkinitcpio hooks are loaded in the correct order..."
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    grep -q "HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)" ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
    hooks_result="$?"
else
    grep -q "HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)" ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
    hooks_result="$?"
fi
if [ "${hooks_result}" -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the mkinitcpio hooks are loaded in the correct order complete."

echo -n "Testing that ParallelDownloads is enabled in Pacman..."
grep -q -P "^ParallelDownloads" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that ParallelDownloads is enabled in Pacman complete."

echo "Testing that the machine-id was reset..."
echo -n "\tChecking that the /etc/machine-id file is empty..."
if [[ "$(cat ${WINESAPOS_INSTALL_DIR}/etc/machine-id)" == "" ]]; then
    echo PASS
else
    echo FAIL
fi
echo -n "\tChecking that /var/lib/dbus/machine-id is a symlink..."
if [[ -L ${WINESAPOS_INSTALL_DIR}/var/lib/dbus/machine-id ]]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the machine-id was reset complete."

echo -n "\tTesting that the offline ClamAV database was downloaded..."
if [[ -f ${WINESAPOS_INSTALL_DIR}/var/lib/clamav/main.cvd ]]; then
    echo PASS
else
    echo FAIL
fi
echo "Testing that the offline ClamAV database was downloaded complete."

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    echo -n "Testing that the firewall has been installed..."
    if [[ -f ${WINESAPOS_INSTALL_DIR}/usr/bin/firewalld ]]; then
        echo PASS
    else
        echo FAIL
    fi
fi

WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
if [[ "${WINESAPOS_CPU_MITIGATIONS}" == "false" ]]; then
    echo -n "Testing that CPU mitigations are disabled in the Linux kernel..."
    grep -q "mitigations=off" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
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
        grep -q "IgnorePkg = linux515 linux515-headers linux510 linux510-headers" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-lts510 linux-lts510-headers" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-lts510 linux-lts510-headers linux-neptune linux-neptune-headers linux-firmware-neptune grub" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi
else
    echo -n "Testing that Pacman is configured to disable conflicting SteamOS package updates..."
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        grep -q "IgnorePkg = linux-lts linux-lts-headers linux-firmware-neptune grub" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi
fi

echo -n 'Checking that the locale has been set to "en_US.UTF-8 UTF-8"...'
arch-chroot ${WINESAPOS_INSTALL_DIR} locale | grep -q "LANG=en_US.UTF-8"
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the hostname is set..."
grep -q -P "^winesapos$" ${WINESAPOS_INSTALL_DIR}/etc/hostname
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the hosts file is configured..."
grep -q -P "^127.0.1.1    winesapos$" ${WINESAPOS_INSTALL_DIR}/etc/hosts
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
        pacman_search_loop krathalans-apparmor-profiles-git
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

echo "Checking that all of the Pamac plugins are enabled..."
for i in EnableAUR CheckAURUpdates EnableFlatpak CheckFlatpakUpdates EnableSnap;
    do echo -n "\t${i}..."
    grep -q -P "^${i}" ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Checking that all of the Pamac plugins are enabled complete."
echo "Testing that the "pamac" package manager is installed complete."

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
  winesapos-mute.service \
  pipewire.service \
  pipewire-pulse.service
    do echo -n "\t${i}..."
    ls "${WINESAPOS_INSTALL_DIR}/home/winesap/.config/systemd/user/default.target.wants/${i}" &> /dev/null
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
ls ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-file-systems.conf &> /dev/null
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi
echo 'Testing that support for all file systems is installed complete.'

echo "Testing that the 'PeaZip' archive manager has been installed..."
if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    pacman_search_loop peazip-gtk2-bin
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    pacman_search_loop peazip-qt-bin
fi
echo "Testing that the 'PeaZip' archive manager has been installed complete."

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    echo "Testing that Steam will not autostart during login..."
    echo -n "Checking that the hook for the 'steamdeck-kde-presets' package exists..."
    if [ -f ${WINESAPOS_INSTALL_DIR}/usr/share/libalpm/hooks/steamdeck-kde-presets.hook ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "Checking that the '/etc/xdg/autostart/steam.desktop' file has the correct permissions..."
    autostart_steam_perms=$(ls -l ${WINESAPOS_INSTALL_DIR}/etc/xdg/autostart/steam.desktop | awk '{print $1}')
    if [[ "${autostart_steam_perms}" == "----------" ]]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that Steam will not autostart during login complete."
fi

echo -n "Checking that the correct operating system was installed..."
grep -q "ID=${WINESAPOS_DISTRO}" ${WINESAPOS_INSTALL_DIR}/etc/os-release
if [ $? -eq 0 ]; then
    echo PASS
else
    echo FAIL
fi

echo -n "Checking that the sudoers file for 'winesap' is correctly configured..."
if [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "true" ]]; then
    grep -q "winesap ALL=(root) NOPASSWD:ALL" ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
elif [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "false" ]]; then
    grep -q "winesap ALL=(root) ALL" ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    if [ $? -eq 0 ]; then
        grep -q "winesap ALL=(root) NOPASSWD: /usr/bin/dmidecode" ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    else
        echo FAIL
    fi
fi

echo "Testing that winesapOS desktop applications exist..."
for i in \
  /home/winesap/.winesapos/winesapos-setup.sh \
  /home/winesap/.winesapos/winesapos-setup.desktop \
  /home/winesap/.config/autostart/winesapos-setup.desktop \
  /home/winesap/Desktop/winesapos-setup.desktop \
  /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh \
  /home/winesap/.winesapos/winesapos-upgrade.desktop \
  /home/winesap/Desktop/winesapos-upgrade.desktop \
  /home/winesap/.winesapos/winesapos_logo_icon.png;
    do echo -n "\t${i}..."
    ls "${WINESAPOS_INSTALL_DIR}${i}" &> /dev/null
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done
echo "Testing that winesapOS desktop applications exist complete."
echo "Tests end time: $(date)"
