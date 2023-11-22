#!/bin/zsh

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(tee /tmp/upgrade_${START_TIME}.log) 2>&1
echo "Start time: ${START_TIME}"

WINESAPOS_UPGRADE_FILES="${WINESAPOS_UPGRADE_FILES:-true}"

# Check for a custom user name. Default to 'winesap'.
ls /tmp/winesapos_user_name.txt &> /dev/null
if [ $? -eq 0 ]; then
    WINESAPOS_USER_NAME=$(cat /tmp/winesapos_user_name.txt)
else
    WINESAPOS_USER_NAME="winesap"
fi

# Download and use the latest 'pacman-static' binary to help deal with partial upgrades until the full system upgrade happens at the end.
# https://github.com/LukeShortCloud/winesapOS/issues/623
CMD_PACMAN="/usr/local/bin/pacman-static"
ls ${CMD_PACMAN}
if [ $? -ne 0 ]; then
    wget https://pkgbuild.com/~morganamilo/pacman-static/x86_64/bin/pacman-static -LO ${CMD_PACMAN}
    chmod +x ${CMD_PACMAN}
fi

VERSION_NEW="$(curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/VERSION)"
WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
CMD_PACMAN_INSTALL=(${CMD_PACMAN} --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u ${WINESAPOS_USER_NAME} yay --pacman ${CMD_PACMAN} --noconfirm -S --needed --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

echo "Setting up tools required for the progress bar..."
${CMD_PACMAN} -Q | grep -q qt5-tools
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} qt5-tools
fi
# SteamOS 3.0 and winesapOS 3.0 ship with the 'qdbus6' binary instead of 'qdbus'.
qdbus_cmd=""
if [ -e /usr/bin/qdbus ]; then
    qdbus_cmd="qdbus"
elif [ -e /usr/bin/qdbus6 ]; then
    qdbus_cmd="qdbus6"
else
    echo "No 'qdbus' command found. The progress bar will not work."
fi
${CMD_PACMAN} -Q | grep -q kdialog
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} kdialog
fi
echo "Setting up tools required for the progress bar complete."

if [[ "${WINESAPOS_UPGRADE_FILES}" == "true" ]]; then
    echo "Upgrading the winesapOS upgrade script..."
    mv /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh "/home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME}"
    wget https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/scripts/winesapos-upgrade-remote-stable.sh -LO /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh
    # If the download fails for any reason, revert back to the original upgrade script.
    if [ $? -ne 0 ]; then
        rm -f /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh
        cp "/home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME}" /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh
    fi
    chmod +x /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh

    mv /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop "/home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop_${START_TIME}"
    wget https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/winesapos-upgrade.desktop -LO /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop
    # If the download fails for any reason, revert back to the original upgrade script.
    if [ $? -ne 0 ]; then
        rm -f /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop
        cp "/home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop_${START_TIME}" /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop
    fi
    chmod +x /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop

    chown -R 1000:1000 /home/${WINESAPOS_USER_NAME}/.winesapos/
    echo "Upgrading the winesapOS upgrade script complete."

    if [[ "$(sha512sum /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh | cut -d' ' -f1)" != "$(sha512sum /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME} | cut -d' ' -f1)" ]]; then
        echo "The winesapOS upgrade script has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
        sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --msgbox "The winesapOS upgrade script has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
        exit 100
    fi

    if [[ "$(sha512sum /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop | cut -d' ' -f1)" != "$(sha512sum /home/${WINESAPOS_USER_NAME}/.winesapos/winesapos-upgrade.desktop_${START_TIME} | cut -d' ' -f1)" ]]; then
        echo "The winesapOS upgrade desktop shortcut has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
        sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --msgbox "The winesapOS upgrade desktop shortcut has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
        exit 100
    fi
else
    echo "Skipping upgrade of winesapOS upgrade files."
fi

kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Please wait for Pacman keyrings to update (this can take a long time)..." 4 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
# SteamOS 3.4 changed the name of the stable repositories.
# https://github.com/LukeShortCloud/winesapOS/issues/537
echo "Switching to new SteamOS release repositories..."
sed -i s'/\[holo\]/\[holo-rel\]/'g /etc/pacman.conf
sed -i s'/\[jupiter\]/\[jupiter-rel\]/'g /etc/pacman.conf
echo "Switching to new SteamOS release repositories complete."
# Update the repository cache.
sudo -E ${CMD_PACMAN} -S -y -y
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
# Update the trusted repository keyrings.
pacman-key --refresh-keys
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    ${CMD_PACMAN} --noconfirm -S archlinux-keyring manjaro-keyring
    pacman-key --populate archlinux manjaro
else
    ${CMD_PACMAN} --noconfirm -S archlinux-keyring
    pacman-key --populate archlinux
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

# Workaround an upstream bug in DKMS.
## https://github.com/LukeShortCloud/winesapOS/issues/427
ln -s /usr/bin/sha512sum /usr/bin/sha512

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.0-rc.0 to 3.0.0 upgrades..." 2 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

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
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.0.0 to 3.0.1 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.0 to 3.0.1 upgrades..." 2 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation..."
grep -q -P "^MAKEFLAGS" /etc/makepkg.conf
if [ $? -ne 0 ]; then
    echo 'MAKEFLAGS="-j $(nproc)"' >> /etc/makepkg.conf
fi
echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation complete."

echo "Running 3.0.0 to 3.0.1 upgrades complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close


echo "Running 3.0.1 to 3.1.0 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.1 to 3.1.0 upgrades..." 11 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

grep -q "\[winesapos\]" /etc/pacman.conf
if [ $? -ne 0 ]; then
    echo "Adding the winesapOS repository..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        sed -i s'/\[jupiter-rel]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\n\n[jupiter-rel]/'g /etc/pacman.conf
    else
        sed -i s'/\[core]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\n\n[core]/'g /etc/pacman.conf
    fi
    echo "Adding the winesapOS repository complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

echo "Enabling newer upstream Arch Linux package repositories..."
if [[ "${WINESAPOS_DISTRO_DETECTED}" != "manjaro" ]]; then
    crudini --set /etc/pacman.conf core Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
    crudini --del /etc/pacman.conf core Include
    crudini --set /etc/pacman.conf extra Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
    crudini --del /etc/pacman.conf extra Include
    crudini --set /etc/pacman.conf multilib Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
    crudini --del /etc/pacman.conf multilib Include
    # TODO: Manjaro has not removed the [community] repository yet but they are working on merging in into [extra] like Arch Linux did.
    # Eventually, the [community] repository will need to be removed for Manjaro.
    # As it stands now, this is only needed for Arch Linux.
    # https://github.com/LukeShortCloud/winesapOS/issues/229#issuecomment-1595865869
    crudini --del /etc/pacman.conf community
fi
# Arch Linux is backward compatible with SteamOS packages but SteamOS is not forward compatible with Arch Linux.
# Move these repositories to the bottom of the Pacman configuration file to account for that.
crudini --del /etc/pacman.conf jupiter
crudini --del /etc/pacman.conf holo
crudini --del /etc/pacman.conf jupiter-rel
crudini --del /etc/pacman.conf holo-rel
crudini --set /etc/pacman.conf jupiter-rel Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
crudini --set /etc/pacman.conf jupiter-rel SigLevel Never
crudini --set /etc/pacman.conf holo-rel Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
crudini --set /etc/pacman.conf holo-rel SigLevel Never

pacman-key --list-keys | grep -q 1805E886BECCCEA99EDF55F081CA29E4A4B01239
if [ $? -ne 0 ]; then
    echo "Adding the public GPG key for the winesapOS repository..."
    pacman-key --recv-keys 1805E886BECCCEA99EDF55F081CA29E4A4B01239
    pacman-key --init
    pacman-key --lsign-key 1805E886BECCCEA99EDF55F081CA29E4A4B01239
    crudini --del /etc/pacman.conf winesapos SigLevel
    echo "Adding the public GPG key for the winesapOS repository complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

sudo -E ${CMD_PACMAN} -S -y -y
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    ${CMD_PACMAN} --noconfirm -S archlinux-keyring manjaro-keyring
else
    ${CMD_PACMAN} --noconfirm -S archlinux-keyring
fi
echo "Enabling newer upstream Arch Linux package repositories complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

# Upgrade glibc. This allows some programs to work during the upgrade process.
${CMD_PACMAN_INSTALL} glibc lib32-glibc

${CMD_PACMAN} -Q | grep -q libpamac-full
if [ $? -eq 0 ]; then
    echo "Replacing Pacmac with bauh..."
    # Do not remove dependencies to keep 'flatpak' and 'snapd' installed.
    # The first '--nodeps' tells Pacman to not remove dependencies.
    # The second '--nodeps' tells is to ignore the packages being required as a dependency for other applications.
    # 'discover' needs 'archlinux-appstream-data' so we will re-install it after this.
    ${CMD_PACMAN} -R -n --nodeps --nodeps --noconfirm archlinux-appstream-data-pamac libpamac-full pamac-all
    ${CMD_PACMAN_INSTALL} archlinux-appstream-data
    ${CMD_YAY_INSTALL} bauh
    rm -f /home/${WINESAPOS_USER_NAME}/Desktop/org.manjaro.pamac.manager.desktop
    cp /usr/share/applications/bauh.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
    chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/bauh.desktop
    chown 1000:1000 /home/${WINESAPOS_USER_NAME}/Desktop/bauh.desktop
    # Enable the 'snapd' service. This was not enabled in winesapOS <= 3.1.1.
    systemctl enable --now snapd
    echo "Replacing Pacmac with bauh complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

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

# Install ProtonUp-Qt as a Flatpak to avoid package conflicts when upgrading to Arch Linux packages.
# https://github.com/LukeShortCloud/winesapOS/issues/375#issuecomment-1146678638
${CMD_PACMAN} -Q | grep -q protonup-qt
if [ $? -eq 0 ]; then
    echo "Installing a newer version of ProtonUp-Qt..."
    ${CMD_PACMAN} -R -n -s --noconfirm protonup-qt
    rm -f /home/${WINESAPOS_USER_NAME}/Desktop/net.davidotek.pupgui2.desktop
    ${CMD_FLATPAK_INSTALL} net.davidotek.pupgui2
    cp /var/lib/flatpak/app/net.davidotek.pupgui2/current/active/export/share/applications/net.davidotek.pupgui2.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
    chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/net.davidotek.pupgui2.desktop
    chown 1000:1000 /home/${WINESAPOS_USER_NAME}/Desktop/net.davidotek.pupgui2.desktop
    echo "Installing a newer version of ProtonUp-Qt complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    ls -1 /etc/modules-load.d/ | grep -q winesapos-controllers.conf
    if [ $? -ne 0 ]; then
        echo "Installing Xbox controller support..."
        ${CMD_YAY_INSTALL} xone-dkms-git
        touch /etc/modules-load.d/winesapos-controllers.conf
        echo -e "xone-wired\nxone-dongle\nxone-gip\nxone-gip-gamepad\nxone-gip-headset\nxone-gip-chatpad\nxone-gip-guitar" | tee /etc/modules-load.d/winesapos-controllers.conf
        for i in xone-wired xone-dongle xone-gip xone-gip-gamepad xone-gip-headset xone-gip-chatpad xone-gip-guitar;
            do modprobe --verbose $i
        done
        echo "Installing Xbox controller support complete."
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    flatpak list | grep -P "^AntiMicroX" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Installing AntiMicroX for changing controller inputs..."
        ${CMD_FLATPAK_INSTALL} io.github.antimicrox.antimicrox
        cp /var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
        chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/io.github.antimicrox.antimicrox.desktop
        chown 1000:1000 /home/${WINESAPOS_USER_NAME}/Desktop/io.github.antimicrox.antimicrox.desktop
        echo "Installing AntiMicroX for changing controller inputs complete."
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

if [[ "${XDG_CURRENT_DESKTOP}" -eq "KDE" ]]; then
    if [ ! -f /usr/bin/kate ]; then
        echo "Installing the simple text editor 'kate'...."
        ${CMD_PACMAN_INSTALL} kate
        echo "Installing the simple text editor 'kate' complete."
    fi
elif [[ "${XDG_CURRENT_DESKTOP}" -eq "X-Cinnamon" ]]; then
    if [ ! -f /usr/bin/xed ]; then
        echo "Installing the simple text editor 'xed'..."
        ${CMD_PACMAN_INSTALL} xed
        echo "Installing the simple text editor 'xed' complete."
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

${CMD_PACMAN} -Q | grep -q linux-firmware-neptune
if [ $? -eq 0 ]; then
    echo "Removing conflicting 'linux-firmware-neptune' packages..."
    ${CMD_PACMAN} -Q linux-firmware-neptune &> /dev/null
    if [ $? -eq 0 ]; then
        ${CMD_PACMAN} -R -n -s --noconfirm linux-firmware-neptune
    fi
    ${CMD_PACMAN} -Q linux-firmware-neptune-rtw-debug &> /dev/null
    if [ $? -eq 0 ]; then
        ${CMD_PACMAN} -R -n -s --noconfirm linux-firmware-neptune-rtw-debug
    fi
    ${CMD_PACMAN_INSTALL} linux-firmware
    echo "Removing conflicting 'linux-firmware-neptune' packages complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9

echo "Upgrading to 'clang' from Arch Linux..."
${CMD_PACMAN} -Q | grep -q clang-libs
if [ $? -eq 0 ]; then
    # SteamOS 3 splits 'clang' (64-bit) into two packages: (1) 'clang' and (2) 'clang-libs'.
    # It does not ship a 'lib32-clang' package.
    ${CMD_PACMAN} -R -d --nodeps --noconfirm clang clang-libs
fi
# Arch Linux has a 'clang' and 'lib32-clang' package.
${CMD_PACMAN_INSTALL} clang lib32-clang
echo "Upgrading to 'clang' from Arch Linux complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 10

echo "Running 3.0.1 to 3.1.0 upgrades complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.1.0 to 3.1.1 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.1.0 to 3.1.1 upgrades..." 2 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

${CMD_PACMAN} -Q | grep -q pipewire-media-session
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -R -d --nodeps --noconfirm pipewire-media-session
    ${CMD_PACMAN_INSTALL} wireplumber
fi

grep -q -P "^GRUB_THEME=/boot/grub/themes/Vimix/theme.txt" /etc/default/grub
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} grub-theme-vimix
    ## This theme needs to exist in the '/boot/' mount because if the root file system is encrypted, then the theme cannot be found.
    mkdir -p /boot/grub/themes/
    cp -R /usr/share/grub/themes/Vimix /boot/grub/themes/Vimix
    crudini --set /etc/default/grub "" GRUB_THEME /boot/grub/themes/Vimix/theme.txt
    ## Target 720p for the GRUB menu as a minimum to support devices such as the GPD Win.
    ## https://github.com/LukeShortCloud/winesapOS/issues/327
    crudini --set /etc/default/grub "" GRUB_GFXMODE 1280x720,auto
    ## Setting the GFX payload to 'text' instead 'keep' makes booting more reliable by supporting all graphics devices.
    ## https://github.com/LukeShortCloud/winesapOS/issues/327
    crudini --set /etc/default/grub "" GRUB_GFXPAYLOAD_LINUX text
    # Remove the whitespace from the 'GRUB_* = ' lines that 'crudini' creates.
    sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" /etc/default/grub
fi
echo "Running 3.1.0 to 3.1.1 upgrades complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.1.1 to 3.2.0 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.1.1 to 3.2.0 upgrades..." 6 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

${CMD_PACMAN} -Q | grep -q linux-steamos
if [ $? -ne 0 ]; then
    ${CMD_PACMAN} -R -d --nodeps --noconfirm linux-neptune linux-neptune-headers
    ${CMD_PACMAN_INSTALL} linux-steamos linux-steamos-headers
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    flatpak list | grep -P "^Flatseal" &> /dev/null
    if [ $? -ne 0 ]; then
        ${CMD_FLATPAK_INSTALL} com.github.tchx84.Flatseal
        cp /var/lib/flatpak/app/com.github.tchx84.Flatseal/current/active/export/share/applications/com.github.tchx84.Flatseal.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
        chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/com.github.tchx84.Flatseal.desktop
        chown 1000:1000 /home/${WINESAPOS_USER_NAME}/Desktop/com.github.tchx84.Flatseal.desktop
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

${CMD_PACMAN} -Q | grep -q game-devices-udev
if [ $? -eq 0 ]; then
    sudo -u ${WINESAPOS_USER_NAME} yay --pacman ${CMD_PACMAN} --noconfirm -S --removemake game-devices-udev
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

${CMD_PACMAN} -Q | grep -q broadcom-wl-dkms
if [ $? -ne 0 ]; then
    echo -e "\nblacklist b43\nblacklist b43legacy\nblacklist bcm43xx\nblacklist bcma\nblacklist brcm80211\nblacklist brcmsmac\nblacklist brcmfmac\nblacklist brcmutil\nblacklist ndiswrapper\nblacklist ssb\nblacklist tg3\n" > /etc/modprobe.d/winesapos.conf
    ${CMD_PACMAN_INSTALL} broadcom-wl-dkms
    echo "wl" >> /etc/modules-load.d/winesapos-wifi.conf
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

# If holo-rel/filesystem is replaced by core/filesystem during an upgrade it can break UEFI boot.
# https://github.com/LukeShortCloud/winesapOS/issues/514
grep -P ^IgnorePkg /etc/pacman.conf  | grep -q filesystem
if [ $? -ne 0 ]; then
    echo "Ignoring the conflicting 'filesystem' package..."
    sed -i s'/IgnorePkg = /IgnorePkg = filesystem /'g /etc/pacman.conf
    echo "Ignoring the conflicting 'filesystem' package complete."
fi
echo "Running 3.1.1 to 3.2.0 upgrades complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.2.0 to 3.2.1 upgrades..."
echo "Switching Steam back to the 'stable' update channel..."
rm -f /home/${WINESAPOS_USER_NAME}/.local/share/Steam/package/beta
echo "Switching Steam back to the 'stable' update channel complete."
echo "Running 3.2.0 to 3.2.1 upgrades complete."

echo "Running 3.2.1 to 3.3.0 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.2.1 to 3.3.0 upgrades..." 14 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
echo "Setting up default text editor..."
grep -q "EDITOR=nano" /etc/environment
if [ $? -eq 0 ]; then
    echo "Default text editor already set. Skipping..."
else
    echo "Default text editor not already set. Proceeding..."
    echo "EDITOR=nano" >> /etc/environment
fi
echo "Setting up default text editor complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

echo "Switching to the new 'vapor-steamos-theme-kde' package..."
${CMD_PACMAN} -Q steamdeck-kde-presets
if [ $? -eq 0 ]; then
    echo "Old 'steamdeck-kde-presets' package detected. Proceeding..."
    rm -f /usr/share/libalpm/hooks/steamdeck-kde-presets.hook
    ${CMD_PACMAN} -R -n --noconfirm steamdeck-kde-presets
    ${CMD_YAY_INSTALL} vapor-steamos-theme-kde
    # Force update "konsole" to get the /etc/xdg/konsolerc file it provides.
    rm -f /etc/xdg/konsolerc
    ${CMD_PACMAN} -S --noconfirm konsole
    # Remove the whitespace from the lines that 'crudini' creates.
    sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" ${WINESAPOS_INSTALL_DIR}/etc/xdg/konsolerc
else
    echo "Old 'steamdeck-kde-presets' package not detected. Skipping..."
fi
echo "Switching to the new 'vapor-steamos-theme-kde' package complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

echo "Switching to the new 'libpipewire' package..."
${CMD_PACMAN} -Q pipewire
if [ $? -eq 0 ]; then
    echo "Old 'pipewire' package detected. Proceeding..."
    ${CMD_PACMAN} -R -n --nodeps --nodeps --noconfirm pipewire lib32-pipewire
    ${CMD_PACMAN_INSTALL} libpipewire lib32-libpipewire
else
    echo "Old 'pipewire' package not detected. Skipping..."
fi
echo "Switching to the new 'libpipewire' package complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

echo "Adding Pacman support to Discover..."
${CMD_PACMAN_INSTALL} packagekit-qt5
echo "Adding Pacman support to Discover complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

echo "Limiting the number of Snapper backups..."
ls /etc/systemd/system/snapper-cleanup-hourly.timer
if [ $? -ne 0 ]; then
    sed -i s'/TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="10"/'g /etc/snapper/configs/root
    sed -i s'/TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="10"/'g /etc/snapper/configs/home
    cat <<EOF > /etc/systemd/system/snapper-cleanup-hourly.timer
[Unit]
Description=Hourly Cleanup of Snapper Snapshots
Documentation=man:snapper(8) man:snapper-configs(5)

[Timer]
OnCalendar=hourly
Persistent=true
Unit=snapper-cleanup.timer

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl disable --now snapper-cleanup.timer
    systemctl enable --now snapper-cleanup-hourly.timer
    systemctl restart snapper-timeline.timer
fi
echo "Limiting the number of Snapper backups complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

echo "Setting 'iwd' as the backend for NetworkManager..."
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
systemctl stop NetworkManager
systemctl disable --now wpa_supplicant
systemctl start NetworkManager
echo "Setting 'iwd' as the backend for NetworkManager complete."

# The extra 'grep' at the end is to only grab the numbers.
# Otherwise, there are invisible special characters in front which cause the float comparison to fail.
YAY_CURRENT_VER=$(yay --version | cut -d" " -f2 | cut -dv -f2 | cut -d. -f1,2 | grep -o -P "[0-9]+.[0-9]+")
if (( $(echo "${YAY_CURRENT_VER} <= 11.1" | bc -l) )); then
    # Check to see if 'yay' or 'yay-git' is installed already.
    ${CMD_PACMAN} -Q | grep -q -P "^yay"
    if [ $? -ne 0 ]; then
        echo "Replacing a manual installation of 'yay' with a package installation..."
        mv /usr/bin/yay /usr/local/bin/yay
        hash -r
        ${CMD_YAY_INSTALL} yay
        rm -f /usr/local/bin/yay
        echo "Replacing a manual installation of 'yay' with a package installation complete."
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

${CMD_PACMAN} -Q | grep appimagepool-appimage
if [ $? -ne 0 ]; then
    echo "Adding the AppImagePool package manager..."
    ${CMD_YAY_INSTALL} appimagelauncher appimagepool-appimage
    cp /usr/share/applications/appimagepool.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
    chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/appimagepool.desktop
    chown 1000:1000 /home/${WINESAPOS_USER_NAME}/Desktop/appimagepool.desktop
    echo "Adding the AppImagePool package manager complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

${CMD_PACMAN} -Q | grep cifs-utils
if [ $? -ne 0 ]; then
    echo "Adding support for the CIFS/SMB file system..."
    ${CMD_PACMAN_INSTALL} cifs-utils
    echo "Adding support for the CIFS/SMB file system done."
fi
${CMD_PACMAN} -Q | grep nfs-utils
if [ $? -ne 0 ]; then
    echo "Adding support for the NFS file system..."
    ${CMD_PACMAN_INSTALL} nfs-utils
    echo "Adding support for the NFS file system done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

${CMD_PACMAN} -Q | grep erofs-utils
if [ $? -ne 0 ]; then
    echo "Adding support for the EROFS file system..."
    ${CMD_PACMAN_INSTALL} erofs-utils
    echo "Adding support for the EROFS file system done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9

${CMD_PACMAN} -Q | grep f2fs-tools
if [ $? -ne 0 ]; then
    echo "Adding support for the F2FS file system..."
    ${CMD_PACMAN_INSTALL} f2fs-tools
    echo "Adding support for the F2FS file system done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 10

${CMD_PACMAN} -Q | grep ssdfs-tools
if [ $? -ne 0 ]; then
    echo "Adding support for the SSDFS file system..."
    ${CMD_YAY_INSTALL} ssdfs-tools
    echo "Adding support for the SSDFS file system done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 11

${CMD_PACMAN} -Q | grep mtools
if [ $? -ne 0 ]; then
    echo "Adding improved support for FAT file systems..."
    ${CMD_PACMAN_INSTALL} mtools
    echo "Adding improved support for FAT file systems done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 12

${CMD_PACMAN} -Q | grep reiserfsprogs
if [ $? -ne 0 ]; then
    echo "Adding support for the ReiserFS file system..."
    # 'cmake' is required to build 'reiserfs-defrag' but is not installed with 'base-devel'.
    ${CMD_PACMAN_INSTALL} reiserfsprogs cmake
    ${CMD_YAY_INSTALL} reiserfs-defrag
    echo "Adding support for the ReiserFS file system done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 13

${CMD_PACMAN} -Q mangohud-common
if [ $? -eq 0 ]; then
    echo "Updating MangoHud to the new package names..."
    ${CMD_PACMAN} -R -n --nodeps --nodeps --noconfirm mangohud-common mangohud lib32-mangohud
    ${CMD_PACMAN_INSTALL} mangohud lib32-mangohud
    echo "Updating MangoHud to the new package names complete."
fi

sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
echo "Running 3.2.1 to 3.3.0 upgrades complete."

echo "Running 3.3.0 to 3.4.0 upgrades..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Running 3.3.0 to 3.4.0 upgrades..." 10 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
# Check to see if Electron from the AUR is installed.
# It is a dependency of balena-etcher but takes along
# time and a lot of disk space to compile.
${CMD_PACMAN} -Q | grep -P "^electron[0-9]+"
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -R -n -s --noconfirm balena-etcher
    export ETCHER_VER="1.18.11"
    wget "https://github.com/balena-io/etcher/releases/download/v${ETCHER_VER}/balenaEtcher-${ETCHER_VER}-x64.AppImage" -O /home/${WINESAPOS_USER_NAME}/Desktop/balenaEtcher.AppImage
    chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/balenaEtcher.AppImage
    rm -f /home/${WINESAPOS_USER_NAME}/Desktop/balena-etcher-electron.desktop
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

${CMD_PACMAN} -Q fprintd
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} fprintd
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

ls /home/deck
if [ $? -ne 0 ]; then
    ln -s /home/winesap /home/deck
fi

${CMD_PACMAN} -Q plasma-wayland-session
if [ $? -ne 0 ]; then
    echo "Adding Wayland support..."
    ${CMD_PACMAN_INSTALL} plasma-wayland-session
    echo "Adding Wayland support complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

${CMD_PACMAN} -Q crudini
if [ $? -eq 0 ]; then
    echo "Replacing 'crudini' with the newer 'python-crudini'..."
    ${CMD_PACMAN} -R -n -s --noconfirm crudini
    # Use the '${CMD_YAY_INSTALL}' without the '--needed' argument to force re-install 'python-iniparse'.
    sudo -u ${WINESAPOS_USER_NAME} yay --pacman ${CMD_PACMAN} --noconfirm -S --removemake python-crudini python-iniparse
    echo "Replacing 'crudini' with the newer 'python-crudini' complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

ls /etc/systemd/system/winesapos-touch-bar-usbmuxd-fix.service
if [ $? -eq 0 ]; then
    echo "Upgrading usbmuxd to work with iPhone devices again even with T2 Mac drivers..."
    systemctl disable --now winesapos-touch-bar-usbmuxd-fix
    rm -f /etc/systemd/system/winesapos-touch-bar-usbmuxd-fix.service
    systemctl daemon-reload
    rm -f /usr/local/bin/winesapos-touch-bar-usbmuxd-fix.sh
    rm -f /usr/lib/udev/rules.d/39-usbmuxd.rules
    wget "https://raw.githubusercontent.com/libimobiledevice/usbmuxd/master/udev/39-usbmuxd.rules.in" -O /usr/lib/udev/rules.d/39-usbmuxd.rules
    echo "Upgrading usbmuxd to work with iPhone devices again even with T2 Mac drivers complete."
fi

systemctl --quiet is-enabled iwd
if [ $? -eq 0 ]; then
    echo "Disabling iwd for better NetworkManager compatibility..."
    # Do not disable '--now' because that would interrupt network connections.
    systemctl disable iwd
    echo "Disabling iwd for better NetworkManager compatibility done."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    ${CMD_PACMAN} -Q gamescope-session-git
    if [ $? -ne 0 ]; then
        echo "Adding Gamescope Session support..."
        ${CMD_YAY_INSTALL} gamescope-session-git gamescope-session-steam-git
        echo "Adding Gamescope Session support complete."
    fi

    ${CMD_PACMAN} -Q opengamepadui-bin
    if [ $? -ne 0 ]; then
        echo "Adding Open Gamepad UI..."
        ${CMD_YAY_INSTALL} opengamepadui-bin opengamepadui-session-git
        echo "Adding Open Gamepad UI complete."
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

${CMD_PACMAN} -Q jfsutils
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} jfsutils
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    ${CMD_PACMAN} -Q openrazer-daemon
    if [ $? -ne 0 ]; then
        ${CMD_PACMAN_INSTALL} openrazer-daemon openrazer-driver-dkms python-pyqt5 python-openrazer razercfg
        sudo gpasswd -a ${WINESAPOS_USER_NAME} plugdev
        systemctl enable --now razerd
        cp /usr/share/applications/razercfg.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
        chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/razercfg.desktop
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

${CMD_PACMAN} -Q vapor-steamos-theme-kde
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -R -n -s --noconfirm vapor-steamos-theme-kde
    ${CMD_YAY_INSTALL} plasma5-themes-vapor-steamos
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "minimal" ]]; then
    ${CMD_PACMAN} -Q oversteer
    if [ $? -ne 0 ]; then
        ${CMD_YAY_INSTALL} oversteer
        cp /usr/share/applications/org.berarma.Oversteer.desktop /home/${WINESAPOS_USER_NAME}/Desktop/
        chmod +x /home/${WINESAPOS_USER_NAME}/Desktop/org.berarma.Oversteer.desktop
    fi
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
echo "Running 3.3.0 to 3.4.0 upgrades complete."

echo "Upgrading system packages..."
kdialog_dbus=$(sudo -E -u ${WINESAPOS_USER_NAME} kdialog --title "winesapOS Upgrade" --progressbar "Please wait for all system packages to upgrade (this can take a long time)..." 9 | cut -d" " -f1)
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog showCancelButton false
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

# Remove the problematic 'fatx' package first.
# https://github.com/LukeShortCloud/winesapOS/issues/651
${CMD_PACMAN} -Q fatx
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -R -n -s --noconfirm fatx
fi

# Remove the problematic 'gwenview' package.
gwenview_found=0
${CMD_PACMAN} -Q gwenview
if [ $? -eq 0 ]; then
    gwenview_found=1
    ${CMD_PACMAN} -R -n -s --noconfirm gwenview
fi

# The 'base-devel' package needs to be explicitly updated since it was changed to a meta package.
# https://github.com/LukeShortCloud/winesapOS/issues/569
sudo -E ${CMD_PACMAN} -S -y --noconfirm base-devel

# On old builds of Mac Linux Gaming Stick, this file is provided by 'filesystem' but is replaced by 'systemd' in newer versions.
# Detect if it is the old version and, if so, delete the conflicting file.
# https://github.com/LukeShortCloud/winesapOS/issues/229#issuecomment-1595868315
grep -q "LC_COLLATE=C" /usr/share/factory/etc/locale.conf
if [ $? -eq 0 ]; then
    rm -f /usr/share/factory/etc/locale.conf
fi

# This upgrade needs to happen before updating the Linux kernels.
# Otherwise, it can lead to an unbootable system.
# https://github.com/LukeShortCloud/winesapOS/issues/379#issuecomment-1166577683
${CMD_PACMAN} -S -u --noconfirm

# Check to see if the previous update failed by seeing if there are still packages to be downloaded for an upgrade.
# If there are, try to upgrade all of the system packages one more time.
sudo -E ${CMD_PACMAN} -S -u -p | grep -P ^http | grep -q tar.zst
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -S -u --noconfirm
fi

sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

flatpak update -y --noninteractive
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
# Remove the Flatpak directory for the user to avoid errors.
# This directory will automatically get re-generated when a 'flatpak' command is ran.
# https://github.com/LukeShortCloud/winesapOS/issues/516
rm -r -f /home/${WINESAPOS_USER_NAME}/.local/share/flatpak

# Remove the old 'ceph-libs' package from the AUR that is no longer used.
# The newer version also fails to compile causing all AUR upgrades to fail.
${CMD_PACMAN} -Q ceph-libs
if [ $? -eq 0 ]; then
    ${CMD_PACMAN} -R -n -s --noconfirm ceph-libs
fi

sudo -u ${WINESAPOS_USER_NAME} yay --pacman ${CMD_PACMAN} -S -y -y -u --noconfirm

# Re-install FATX by re-compiling it from the AUR.
${CMD_YAY_INSTALL} aur/fatx
# Re-install gwenview.
if [[ "${gwenview_found}" == "1" ]]; then
    ${CMD_PACMAN_INSTALL} gwenview
fi

# Re-add this setting for the Plasma 5 Vapor theme after the system upgrade is complete.
crudini --set /etc/xdg/konsolerc "Desktop Entry" DefaultProfile Vapor.profile
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
echo "Upgrading system packages complete."

echo "Upgrading ignored packages..."
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]]; then
    yes | ${CMD_PACMAN} -S core/linux-lts core/linux-lts-headers winesapos/linux-lts515 winesapos/linux-lts515-headers core/grub core/filesystem
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    yes | ${CMD_PACMAN} -S core/linux61 core/linux61-headers core/linux515 core/linux515-headers core/grub
    # Due to conflicts between Mac Linux Gaming Stick 2 versus winesapOS 3, do not replace the 'filesystem' package.
    # https://github.com/LukeShortCloud/winesapOS/issues/229#issuecomment-1595886615
    if [[ "${WINESAPOS_USER_NAME}" == "stick" ]]; then
	yes | ${CMD_PACMAN} -S core/filesystem
    else
	yes | ${CMD_PACMAN} -S holo-rel/filesystem
    fi
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
    yes | ${CMD_PACMAN} -S core/linux-lts core/linux-lts-headers linux-steamos linux-steamos-headers core/grub holo-rel/filesystem
fi
echo "Upgrading ignored packages done."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

${CMD_PACMAN} -Q | grep -q nvidia-dkms
if [ $? -eq 0 ]; then
    echo "Upgrading NVIDIA drivers..."
    ${CMD_PACMAN} -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia
    echo "Upgrading NVIDIA drivers complete."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

dmidecode -s system-product-name | grep -P ^Mac
if [ $? -eq 0 ]; then
    echo "Mac hardware detected."

    ${CMD_PACMAN} -Q mbpfan-git
    if [ $? -ne 0 ]; then
        echo "Installing MacBook fan support..."
        ${CMD_YAY_INSTALL} mbpfan-git
        crudini --set /etc/mbpfan.conf general min_fan_speed 1300
        crudini --set /etc/mbpfan.conf general max_fan_speed 6200
        crudini --set /etc/mbpfan.conf general max_temp 105
        systemctl enable --now mbpfan
        echo "Installing MacBook fan support complete."
    fi

    echo "Re-installing Mac drivers..."
    # Sound driver for Linux LTS 6.1.
    # https://github.com/LukeShortCloud/winesapOS/issues/152
    # https://github.com/LukeShortCloud/winesapOS/issues/614
    # First, clean up old driver files that may exist.
    rm -r -f /snd-hda-codec-cs8409
    git clone --branch linux5.19 https://github.com/egorenar/snd-hda-codec-cs8409.git
    cd snd-hda-codec-cs8409
    # The last kernel found from the 'tail' command is actually the newest one.
    export KVER=$(ls -1 /lib/modules/ | grep -P "^6.1." | tail -n 1)
    make
    make install
    cd ..
    rm -rf snd-hda-codec-cs8409
    # The old "linux5.14" branch created a module called "snd-hda-codec-cirrus".
    # The new "linux5.19" branch creates a module called "snd-hda-codec-cs8409".
    echo "snd-hda-codec-cs8409" > /etc/modules-load.d/winesapos-sound.conf

    # Reinstall the MacBook Pro Touch Bar driver to force the DKMS to re-install on all kernels.
    sudo -u ${WINESAPOS_USER_NAME} yay --pacman ${CMD_PACMAN} --noconfirm -S --removemake macbook12-spi-driver-dkms
    ${CMD_YAY_INSTALL} macbook12-spi-driver-dkms
    for kernel in $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+"); do
        dkms install --no-depmod macbook12-spi-driver/$(${CMD_PACMAN} -Q macbook12-spi-driver-dkms | awk {'print $2'} | cut -d- -f1) -k ${kernel} --force
    done

    for kernel in $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+"); do
        # This will sometimes fail the first time it tries to install.
        timeout 120s dkms install -m apple-bce -v 0.1 -k ${kernel}
        if [ $? -ne 0 ]; then
            dkms install -m apple-bce -v 0.1 -k ${kernel}
        fi
    done
    echo "Re-installing Mac drivers done."
else
    echo "No Mac hardware detected."
fi
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

# winesapOS 3.0.Y will have broken UEFI boot after an upgrade so we need to re-install it.
# Legacy BIOS boot is unaffected.
# https://github.com/LukeShortCloud/winesapOS/issues/695
grep "3.0*" /etc/winesapos/VERSION
if [ $? -eq 0 ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS --removable
fi

echo "Rebuilding initramfs with new drivers..."
mkinitcpio -P
echo "Rebuilding initramfs with new drivers complete."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

echo "Updating Btrfs snapshots in the GRUB menu..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "Updating Btrfs snapshots in the GRUB menu complete."

echo "Enabling Flatpaks to update upon reboot for NVIDIA systems..."
ls /etc/systemd/system/winesapos-flatpak-update.service
if [ $? -ne 0 ]; then
    curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/winesapos-flatpak-update.service -L -o /etc/systemd/system/winesapos-flatpak-update.service
    systemctl daemon-reload
fi
systemctl enable winesapos-flatpak-update.service
echo "Enabling Flatpaks to update upon reboot for NVIDIA systems complete."

echo "VERSION_ORIGINAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
sudo -E -u ${WINESAPOS_USER_NAME} ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
echo "End time: $(date --iso-8601=seconds)"

if [[ "${WINESAPOS_USER_NAME}" == "stick" ]]; then
    mv /tmp/upgrade_${START_TIME}.log /etc/mac-linux-gaming-stick/
else
    mv /tmp/upgrade_${START_TIME}.log /etc/winesapos/
fi
