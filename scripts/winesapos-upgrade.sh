#!/bin/zsh

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(tee /etc/winesapos/upgrade_${START_TIME}.log) 2>&1
echo "Start time: $(date --iso-8601=seconds)"

VERSION_NEW="3.1.0"
WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u winesap yay --noconfirm -S --needed --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

# Update the repository cache.
pacman -Sy
# Update the trusted repository keyrings.
pacman --noconfirm -S archlinux-keyring manjaro-keyring

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades..."

echo "Upgrading exFAT partition to work on Windows..."
# Example output: "vda2" or "nvme0n1p2"
exfat_partition_device_name_short=$(lsblk -o name,label | grep wos-drive | awk '{print $1}' | grep -o -P '[a-z]+.*')
exfat_partition_device_name_full="/dev/${exfat_partition_device_name_short}"
# Example output: 2
exfat_partition_number=$(echo ${exfat_partition_device_name_short} | grep -o -P "[0-9]+$")

echo ${exfat_partition_device_name_short} | grep -q nvme
if [ $? -eq 0 ]; then
    # Example output: /dev/nvme0n1
    root_device=$(echo "${exfat_partition_device_name_full}" | grep -P -o "/dev/nvme[0-9]+n[0-9]+")
else
    # Example output: /dev/vda
    root_device=$(echo "${exfat_partition_device_name_full}" | sed s'/[0-9]//'g)
fi
parted ${root_device} set ${exfat_partition_number} msftdata on
echo "Upgrading exFAT partition to work on Windows complete."

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades complete."

echo "Running 3.0.0 to 3.0.1 upgrades..."

echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation..."
grep -q -P "^MAKEFLAGS" /etc/makepkg.conf
if [ $? -ne 0 ]; then
    echo 'MAKEFLAGS="-j $(nproc)"' >> /etc/makepkg.conf
fi
echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation complete."

pacman -Q libpamac-full | grep -q -P "libpamac-full 1:11.2.0-5"
if [ $? -eq 0 ]; then
    echo "Fixing broken 'libpamac-full' package..."
    # Workaround a short-term bug where 'pamac-all' fails due to broken dependencies.
    # We install known working versions of the dependencies.
    # https://github.com/LukeShortCloud/winesapOS/issues/318
    ## Install 'paru' as it supports building PKGBUILD files and installing dependencies (unlike 'yay').
    ## https://github.com/Jguer/yay/issues/694
    ### 'paru' has a bug where it does not install checkdepends dependencies from a PKGBUILD so we need to manually install those first.
    ### https://github.com/Morganamilo/paru/issues/718
    ${CMD_YAY_INSTALL} paru
    ### checkdepends for vala.
    ${CMD_PACMAN_INSTALL} gobject-introspection
    ### vala 0.54.6-1.
    sudo -u winesap /bin/sh -c 'mkdir /tmp/vala/; cd /tmp/vala; wget https://raw.githubusercontent.com/archlinux/svntogit-packages/9b2b7e9e326dff5af4d3ee49f5b3971462a046ff/trunk/PKGBUILD; paru -U -i --noconfirm --removemake'
    ### checkdepends for libpamac-full.
    ${CMD_PACMAN_INSTALL} itstool meson ninja asciidoc
    ### libpamac-full 11.2.0-1.
    sudo -u winesap /bin/sh -c 'mkdir /tmp/libpamac-full; cd /tmp/libpamac-full; wget https://aur.archlinux.org/cgit/aur.git/snapshot/aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85.tar.gz; tar -xvf aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85.tar.gz; cd aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85; paru -U -i --noconfirm --removemake'
    ${CMD_YAY_INSTALL} pamac-all
    echo "Fixing broken 'libpamac-full' package done."
fi

echo "Running 3.0.0 to 3.0.1 upgrades complete."


echo "Running 3.0.1 to 3.1.0 upgrades..."

grep -q "[winesapos]" /etc/pacman.conf
if [ $? -eq 0 ]; then
    echo "Adding the winesapOS repository..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        sed -i s'/\[jupiter]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[jupiter]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    else
        sed -i s'/\[core]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[core]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    fi
    echo "Adding the winesapOS repository complete."
fi
pacman -S -y -y

grep -q tmpfs /etc/fstab
if [ $? -ne 0 ]; then
    echo "Switching volatile mounts from 'ramfs' to 'tmpfs' for compatibility with FUSE (used by AppImage and Flatpak packages)..."
    sed -i s'/ramfs/tmpfs/'g /etc/fstab
    echo "Switching volatile mounts from 'ramfs' to 'tmpfs' for compatibility with FUSE (used by AppImage and Flatpak packages) complete."
fi

# This is a new package in SteamOS 3.2 that will replace 'linux-firmware' which can lead to unbootable systems.
# https://github.com/LukeShortCloud/winesapOS/issues/372
grep -q linux-firmware-neptune-rtw-debug /etc/pacman.conf
if [ $? -ne 0 ]; then
    echo "Ignoring the new conflicting linux-firmware-neptune-rtw-debug package..."
    sed -i s'/IgnorePkg = /IgnorePkg = linux-firmware-neptune-rtw-debug /'g /etc/pacman.conf
    echo "Ignoring the new conflicting linux-firmware-neptune-rtw-debug package complete."
fi

echo "Enabling newer upstream Arch Linux package repositories..."
crudini --set /etc/pacman.conf core Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
crudini --del /etc/pacman.conf core Include
crudini --set /etc/pacman.conf extra Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
crudini --del /etc/pacman.conf extra Include
crudini --set /etc/pacman.conf community Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
crudini --del /etc/pacman.conf community Include
crudini --set /etc/pacman.conf multilib Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
crudini --del /etc/pacman.conf multilib Include
# Arch Linux is backward compatible with SteamOS packages but SteamOS is not forward compatible with Arch Linux.
# Move these repositories to the bottom of the Pacman configuration file to account for that.
crudini --del /etc/pacman.conf jupiter
crudini --del /etc/pacman.conf holo
crudini --set /etc/pacman.conf jupiter Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
crudini --set /etc/pacman.conf jupiter SigLevel Never
crudini --set /etc/pacman.conf holo Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
crudini --set /etc/pacman.conf holo SigLevel Never
pacman -S -y -y
# Install ProtonUp-Qt as a Flatpak to avoid package conflicts when upgrading to Arch Linux packages.
# https://github.com/LukeShortCloud/winesapOS/issues/375#issuecomment-1146678638
pacman -R -n -s --noconfirm protonup-qt
${CMD_FLATPAK_INSTALL} net.davidotek.pupgui2
echo "Enabling newer upstream Arch Linux package repositories complete."

ls -1 /etc/modules-load.d/ | grep -q winesapos-controllers.conf
if [ $? -ne 0 ]; then
    echo "Installing Xbox controller support..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        ${CMD_PACMAN_INSTALL} holo/xone-dkms-git
    else
        ${CMD_YAY_INSTALL} xone-dkms-git
    fi
    touch /etc/modules-load.d/winesapos-controllers.conf
    echo -e "xone-wired\nxone-dongle\nxone-gip\nxone-gip-gamepad\nxone-gip-headset\nxone-gip-chatpad\nxone-gip-guitar" | tee /etc/modules-load.d/winesapos-controllers.conf
    for i in xone-wired xone-dongle xone-gip xone-gip-gamepad xone-gip-headset xone-gip-chatpad xone-gip-guitar;
        do modprobe --verbose $i
    done
    echo "Installing Xbox controller support complete."
fi

flatpak list | grep -P "^AntiMicroX" &> /dev/null
if [ $? -ne 0 ]; then
    echo "Installing AntiMicroX for changing controller inputs..."
    ${CMD_FLATPAK_INSTALL} io.github.antimicrox.antimicrox
    cp /var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop /home/winesap/Desktop/
    chown winesap.winesap /home/winesap/Desktop/io.github.antimicrox.antimicrox.desktop
    echo "Installing AntiMicroX for changing controller inputs complete."
fi

echo "Running 3.0.1 to 3.1.0 upgrades complete."

echo "VERSION_ORIGNIAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
echo "End time: $(date --iso-8601=seconds)"
