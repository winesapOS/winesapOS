#!/bin/zsh

WINESAPOS_DEBUG_TESTS="${WINESAPOS_DEBUG_TESTS:-false}"
if [[ "${WINESAPOS_DEBUG_TESTS}" == "true" ]]; then
    set -x
else
    set +x
fi

echo "Tests start time: $(date)"

WINESAPOS_DEVICE="${WINESAPOS_DEVICE:-vda}"

if [[ "${WINESAPOS_CREATE_DEVICE}" == "true" ]];
    then DEVICE="/dev/loop0"
else
    DEVICE="/dev/${WINESAPOS_DEVICE}"
fi

WINESAPOS_INSTALL_DIR="${WINESAPOS_INSTALL_DIR:-/winesapos}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-steamos}"
WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
WINESAPOS_ENABLE_TESTING_REPO="${WINESAPOS_ENABLE_TESTING_REPO:-false}"
WINESAPOS_DE="${WINESAPOS_DE:-plasma}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
WINESAPOS_SUDO_NO_PASSWORD="${WINESAPOS_SUDO_NO_PASSWORD:-true}"
WINESAPOS_ENABLE_KLIPPER="${WINESAPOS_ENABLE_KLIPPER:-true}"
WINESAPOS_ENABLE_PORTABLE_STORAGE="${WINESAPOS_ENABLE_PORTABLE_STORAGE:-true}"
WINESAPOS_INSTALL_GAMING_TOOLS="${WINESAPOS_INSTALL_GAMING_TOOLS:-true}"
WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS="${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS:-true}"
WINESAPOS_AUTO_LOGIN="${WINESAPOS_AUTO_LOGIN:-true}"
WINESAPOS_BUILD_CHROOT_ONLY="${WINESAPOS_BUILD_CHROOT_ONLY:-false}"

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    DEVICE_WITH_PARTITION="${DEVICE}"
    echo ${DEVICE} | grep -q -P "^/dev/(nvme|loop)"
    if [ $? -eq 0 ]; then
        # "nvme" and "loop" devices separate the device name and partition number by using a "p".
        # Example output: /dev/loop0p
        DEVICE_WITH_PARTITION="${DEVICE}p"
    fi

    DEVICE_WITH_PARTITION_SHORT=$(echo ${DEVICE_WITH_PARTITION} | cut -d/ -f3)

    # Required to change the default behavior to Zsh to fail and exit
    # if a '*' glob is not found.
    # https://github.com/LukeShortCloud/winesapOS/issues/137
    setopt +o nomatch

    echo "Testing partitions..."
    lsblk_f_output=$(lsblk -f)

    echo -n "Checking that ${DEVICE_WITH_PARTITION}1 is not formatted..."
    echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}1     "
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        echo -n "Checking that ${DEVICE_WITH_PARTITION}2 is formatted as exFAT..."
        echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}2.*exfat"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi

        echo -n "Checking that ${DEVICE_WITH_PARTITION}2 has the 'msftdata' partition flag..."
        parted ${DEVICE} print | grep -q msftdata
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        echo -n "Checking that ${DEVICE_WITH_PARTITION}3 is formatted as FAT32..."
        echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}3.*vfat"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    else
        echo -n "Checking that ${DEVICE_WITH_PARTITION}2 is formatted as FAT32..."
        echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}2.*vfat"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        echo -n "Checking that ${DEVICE_WITH_PARTITION}4 is formatted as ext4..."
        echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}4.*ext4"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    else
        echo -n "Checking that ${DEVICE_WITH_PARTITION}3 is formatted as ext4..."
        echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}3.*ext4"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        echo -n "Checking that ${DEVICE_WITH_PARTITION}5 is formatted as Btrfs..."
        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            echo ${lsblk_f_output} | grep -q "cryptroot btrfs"
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        else
            echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}5 btrfs"
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        fi
    else
        echo -n "Checking that ${DEVICE_WITH_PARTITION}4 is formatted as Btrfs..."
        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            echo ${lsblk_f_output} | grep -q "cryptroot btrfs"
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        else
            echo ${lsblk_f_output} | grep -q "${DEVICE_WITH_PARTITION_SHORT}4 btrfs"
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        fi
    fi

    echo -n "Testing partitions complete.\n\n"

    echo "Testing /etc/fstab mounts..."

    echo "Checking that each mount exists in /etc/fstab..."
    for i in \
      "^LABEL=.*\s+/\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard" \
      "^LABEL=.*\s+/home\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
      "^LABEL=.*\s+/swap\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
      "^(none|tmpfs)\s+/tmp\s+tmpfs\s+rw.*\s+0\s+0" \
      "^(none|tmpfs)\s+/var/log\s+tmpfs\s+rw.*\s+0\s+0" \
      "^(none|tmpfs)\s+/var/tmp\s+tmpfs\s+rw.*\s+0\s+0"
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
fi

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

echo "Testing package repositories..."

echo -n "Checking that the winesapOS repository was added..."
if [[ "${WINESAPOS_ENABLE_TESTING_REPO}" == "false" ]]; then
    grep -q -P "^\[winesapos\]" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
else
    grep -q -P "^\[winesapos-testing\]" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi
echo "Testing package repositories complete."

echo "Testing package installations..."

function pacman_search() {
    chroot ${WINESAPOS_INSTALL_DIR} pacman -Qsq ${1} &> /dev/null
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

function flatpak_search() {
    chroot ${WINESAPOS_INSTALL_DIR} flatpak list | grep -P "^${1}" &> /dev/null
}

function flatpak_search_loop() {
    for i in ${@}
        do echo -n "\t${i}..."
        flatpak_search "${i}"
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

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Checking that the Linux kernel packages are installed..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        pacman_search_loop linux510 linux510-headers linux515 linux515-headers linux-firmware
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        pacman_search_loop linux-lts510 linux-lts510-headers linux-lts linux-lts-headers linux-firmware
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        pacman_search_loop linux-lts linux-lts-headers linux-firmware linux-steamos linux-steamos-headers
    fi

    WINESAPOS_EXTRA_LINUX_FIRMWARE="${WINESAPOS_EXTRA_LINUX_FIRMWARE:-true}"
    if [[ "${WINESAPOS_EXTRA_LINUX_FIRMWARE}" == "true" ]]; then
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
    fi
fi

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    echo "Checking that gaming tools are installed..."
    pacman_search_loop \
      gamemode \
      lib32-gamemode \
      gamescope \
      goverlay \
      heroic-games-launcher-bin \
      lutris \
      mangohud \
      lib32-mangohud \
      replay-sorcery \
      vkbasalt \
      lib32-vkbasalt \
      wine-staging \
      zerotier-one \
      zerotier-gui-git

    flatpak_search_loop \
      AntiMicroX \
      Bottles \
      Discord \
      OBS \
      PolyMC \
      Protontricks \
      ProtonUp-Qt
fi

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    echo "Checking that other Flatpaks are installed..."
    flatpak_search_loop \
      Cheese \
      ClamTk \
      KeePassXC \
      LibreOffice \
      PeaZip \
      Transmission \
      VLC
fi

echo "Checking that the desktop environment packages are installed..."
pacman_search_loop \
  xorg-server \
  lib32-mesa-steamos \
  mesa-steamos \
  xorg-server \
  xorg-xinit \
  xterm \
  xf86-input-libinput

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    pacman_search_loop \
      cinnamon \
      lightdm \
      xorg-server \
      xed

    flatpak_search_loop \
      Pix

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
      kate

    flatpak_search_loop \
      Gwenview

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

if [[ "${WINESAPOS_AUTO_LOGIN}" == "true" ]]; then
    echo -n "Checking that auto login is enabled..."
    grep -q "autologin-user = winesap" ${WINESAPOS_INSTALL_DIR}/etc/lightdm/lightdm.conf
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

echo "Checking that Bluetooth packages are installed..."
pacman_search_loop bluez bluez-utils blueman bluez-qt
echo "Checking that Bluetooth packages are installed complete."

echo -n "Checking that the 'bluetooth' service is enabled..."
chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled bluetooth.service
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
  winesapos-touch-bar-usbmuxd-fix
    do echo -n "\t${i}..."
    chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
done

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled zerotier-one
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    i="pacman-mirrors"
    echo -n "\t${i}..."
    chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    i="reflector.service"
    echo -n "\t${i}..."
    chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled ${i}
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo -n "\tapparmor..."
    chroot ${WINESAPOS_INSTALL_DIR} systemctl --quiet is-enabled apparmor
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
fi

echo -n "Testing that services are enabled complete.\n\n"

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Testing the bootloader..."

    echo -n "Checking that GRUB 2 has been installed..."
    pacman -S --noconfirm binutils > /dev/null
    dd if=${DEVICE} bs=512 count=1 2> /dev/null | strings | grep -q GRUB
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

    echo -n "Checking that the Vimix theme for GRUB exists..."
    if [ -f ${WINESAPOS_INSTALL_DIR}/boot/grub/themes/Vimix/theme.txt ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "Checking that the Vimix theme for GRUB is enabled..."
    grep -q -P "^GRUB_THEME=/boot/grub/themes/Vimix/theme.txt" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "Checking that GRUB is set to use resolutions supported by our theme..."
    grep -q -P "^GRUB_GFXMODE=1280x720,auto" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "Checking that GRUB is set to use the text GFX payload for better boot compatibility..."
    grep -q -P "^GRUB_GFXPAYLOAD_LINUX=text" ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing the bootloader complete."
fi

echo "Testing that 'yay' is installed..."
echo -n "Checking for the 'yay' binary..."
if [ -f ${WINESAPOS_INSTALL_DIR}/usr/bin/yay ]; then
    echo PASS
else
    echo FAIL
fi

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        echo "Checking that the 'yay-git' package is installed..."
        pacman_search_loop yay-git
        echo "Checking that the 'yay-git' package is installed complete."
    fi
fi
echo -n "Testing that 'yay' is complete..."

echo "Testing desktop shortcuts..."
for i in \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/bauh.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/blueman-manager.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/firefox-esr.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/terminator.desktop \
  ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/README.txt
    do echo -n "\tChecking if the file ${i} exists..."
    if [ -f "${i}" ]; then
      echo PASS
    else
      echo FAIL
    fi
done

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then

    for i in \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/io.github.antimicrox.antimicrox.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.usebottles.bottles.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.discordapp.Discord.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/io.github.benjamimgois.goverlay.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/ludusavi.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.obsproject.Studio.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/net.davidotek.pupgui2.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/zerotier-gui.desktop
        do echo -n "\tChecking if the file ${i} exists..."
        if [ -f "${i}" ]; then
          echo PASS
        else
          echo FAIL
        fi
    done

    for i in \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.polymc.PolyMC.desktop
        do echo -n "\tChecking if gamemoderun is configured for file ${i}..."
        grep -q -P "^Exec=/usr/bin/gamemoderun " "${i}"
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    done

fi

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    for i in \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.gnome.Cheese.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.gitlab.davem.ClamTk.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/balena-etcher-electron.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.keepassxc.KeePassXC.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.libreoffice.LibreOffice.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/io.github.peazip.PeaZip.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/qdirstat.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/shutter.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/com.transmissionbt.Transmission.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/veracrypt.desktop \
      ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.videolan.VLC.desktop
        do echo -n "\tChecking if the file ${i} exists..."
        if [ -f "${i}" ]; then
          echo PASS
        else
          echo FAIL
        fi
    done
fi

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
    x=("${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/nemo.desktop" "${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.kde.pix.desktop")
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

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    echo "Testing that Wine packages have been installed..."
    echo -n "\tChecking that Wine GE is installed..."
    ls -1 ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/lutris/runners/wine/ | grep -q -P "^lutris-GE-Proton.*"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "\tChecking that the Protontricks wrapper script is installed..."
    ls ${WINESAPOS_INSTALL_DIR}/usr/local/bin/protontricks &> /dev/null
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that Wine packages have been installed complete."
fi

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

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    echo "Testing that the offline ClamAV databases were downloaded..."
    for i in bytecode.cvd daily.cvd main.cvd; do
        echo -n "\t${i}..."
        if [[ -f ${WINESAPOS_INSTALL_DIR}/home/winesap/.var/app/com.gitlab.davem.ClamTk/data/.clamtk/db/${i} ]]; then
            echo PASS
        else
            echo FAIL
        fi
    done
    echo "Testing that the offline ClamAV databases were downloaded complete."
fi

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
        if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
            grep -q "IgnorePkg = linux-lts linux-lts-headers linux-steamos linux-steamos-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug grub" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        else
            grep -q "IgnorePkg = linux-lts linux-lts-headers linux-steamos linux-steamos-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        fi
    fi
else
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
            echo -n "Testing that Pacman is configured to disable conflicting SteamOS package updates..."
            grep -q "IgnorePkg = linux-lts linux-lts-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug grub" ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
            if [ $? -eq 0 ]; then
                echo PASS
            else
                echo FAIL
            fi
        fi
    fi
fi

echo -n 'Checking that the locale has been set...'
chroot ${WINESAPOS_INSTALL_DIR} locale --all-locales | grep -i "en_US.utf8"
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
    bauh \
    cloud-guest-utils \
    crudini \
    hfsprogs \
    macbook12-spi-driver-dkms \
    python-iniparse \
    snapd

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    pacman_search_loop \
      firefox-esr-bin \
      qdirstat
fi

if [[ "${WINESAPOS_DISTRO_DETECTED}" != "manjaro" ]]; then
    pacman_search_loop \
      lightdm-settings \
      oh-my-zsh-git \
      zsh
    if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
        pacman_search_loop \
          apparmor \
          krathalans-apparmor-profiles-git
    fi
else
    pacman_search_loop \
      oh-my-zsh \
      zsh
    if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
        pacman_search_loop \
          apparmor \
          apparmor-profiles
    fi
fi
echo "Checking that all the packages from the AUR have been installed by yay done."

echo 'Testing that the PipeWire audio library is installed...'
echo "Checking that PipeWire packages are installed..."
pacman_search_loop \
  pavucontrol \
  pipewire \
  lib32-pipewire \
  pipewire-alsa \
  pipewire-jack \
  lib32-pipewire-jack \
  pipewire-pulse \
  pipewire-v4l2 \
  lib32-pipewire-v4l2 \
  wireplumber
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

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    if [[ "${WINESAPOS_DE}" == "plasma" ]]; then
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

if [[ "${WINESAPOS_ENABLE_KLIPPER}" == "false" ]]; then
    echo "Testing that Klipper has been disabled..."
    echo "Checking that Klipper settings are configured..."
    for i in "KeepClipboardContents = false" "MaxClipItems = 1" "PreventEmptyClipboard = false";
	do echo -n -e "\t${i}..."
	grep -q -P "^${i}" ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/klipperrc
        if [ $? -eq 0 ]; then
            echo PASS
        else
            echo FAIL
        fi
    done
    echo -n "Checking that the Klipper directory is mounted as a RAM file system..."
    grep -q 'ramfs    /home/winesap/.local/share/klipper    ramfs    rw,nosuid,nodev    0 0' ${WINESAPOS_INSTALL_DIR}/etc/fstab
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that Klipper has been disabled complete."
fi
echo "Tests end time: $(date)"
