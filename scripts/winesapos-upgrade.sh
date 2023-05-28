#!/bin/zsh

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(tee /etc/winesapos/upgrade_${START_TIME}.log) 2>&1
echo "Start time: ${START_TIME}"

VERSION_NEW="$(curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/VERSION)"
WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u winesap yay --noconfirm -S --needed --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

echo "Upgrading the winesapOS upgrade script..."
mv /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh "/home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME}"
wget https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/scripts/winesapos-upgrade-remote-stable.sh -LO /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh
# If the download fails for any reason, revert back to the original upgrade script.
if [ $? -ne 0 ]; then
    rm -f /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh
    cp "/home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME}" /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh
fi
chmod +x /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh

mv /home/winesap/.winesapos/winesapos-upgrade.desktop "/home/winesap/.winesapos/winesapos-upgrade.desktop_${START_TIME}"
wget https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/winesapos-upgrade.desktop -LO /home/winesap/.winesapos/winesapos-upgrade.desktop
# If the download fails for any reason, revert back to the original upgrade script.
if [ $? -ne 0 ]; then
    rm -f /home/winesap/.winesapos/winesapos-upgrade.desktop
    cp "/home/winesap/.winesapos/winesapos-upgrade.desktop_${START_TIME}" /home/winesap/.winesapos/winesapos-upgrade.desktop
fi
chmod +x /home/winesap/.winesapos/winesapos-upgrade.desktop

chown -R winesap.winesap /home/winesap/.winesapos/
echo "Upgrading the winesapOS upgrade script complete."


echo "Setting up tools required for the progress bar..."
pacman -Q | grep -q qt5-tools
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
pacman -Q | grep -q kdialog
if [ $? -ne 0 ]; then
    ${CMD_PACMAN_INSTALL} kdialog
fi
echo "Setting up tools required for the progress bar complete."


if [[ "$(sha512sum /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh | cut -d' ' -f1)" != "$(sha512sum /home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh_${START_TIME} | cut -d' ' -f1)" ]]; then
    echo "The winesapOS upgrade script has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
    sudo -E -u winesap kdialog --title "winesapOS Upgrade" --msgbox "The winesapOS upgrade script has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
    exit 100
fi

if [[ "$(sha512sum /home/winesap/.winesapos/winesapos-upgrade.desktop | cut -d' ' -f1)" != "$(sha512sum /home/winesap/.winesapos/winesapos-upgrade.desktop_${START_TIME} | cut -d' ' -f1)" ]]; then
    echo "The winesapOS upgrade desktop shortcut has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
    sudo -E -u winesap kdialog --title "winesapOS Upgrade" --msgbox "The winesapOS upgrade desktop shortcut has been updated. Please re-run the 'winesapOS Upgrade' desktop shortcut."
    exit 100
fi


kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Please wait for Pacman keyrings to update (this can take a long time)..." 4 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
# SteamOS 3.4 changed the name of the stable repositories.
# https://github.com/LukeShortCloud/winesapOS/issues/537
echo "Switching to new SteamOS release repositories..."
sed -i s'/\[holo\]/\[holo-rel\]/'g /etc/pacman.conf
sed -i s'/\[jupiter\]/\[jupiter-rel\]/'g /etc/pacman.conf
echo "Switching to new SteamOS release repositories complete."
# Update the repository cache.
pacman -S -y -y
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
# Update the trusted repository keyrings.
pacman-key --refresh-keys
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    pacman --noconfirm -S archlinux-keyring manjaro-keyring
    pacman-key --populate archlinux manjaro
else
    pacman --noconfirm -S archlinux-keyring
    pacman-key --populate archlinux
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

# Workaround an upstream bug in DKMS.
## https://github.com/LukeShortCloud/winesapOS/issues/427
ln -s /usr/bin/sha512sum /usr/bin/sha512

echo "Running 3.0.0-rc.0 to 3.0.0 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.0-rc.0 to 3.0.0 upgrades..." 2 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.0.0 to 3.0.1 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.0 to 3.0.1 upgrades..." 2 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation..."
grep -q -P "^MAKEFLAGS" /etc/makepkg.conf
if [ $? -ne 0 ]; then
    echo 'MAKEFLAGS="-j $(nproc)"' >> /etc/makepkg.conf
fi
echo "Upgrading 'makepkg' and 'yay' to use all available processor cores for compilation complete."

echo "Running 3.0.0 to 3.0.1 upgrades complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close


echo "Running 3.0.1 to 3.1.0 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.0.1 to 3.1.0 upgrades..." 12 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

grep -q "\[winesapos\]" /etc/pacman.conf
if [ $? -ne 0 ]; then
    echo "Adding the winesapOS repository..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        sed -i s'/\[jupiter-rel]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[jupiter-rel]/'g /etc/pacman.conf
    else
        sed -i s'/\[core]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[core]/'g /etc/pacman.conf
    fi
    echo "Adding the winesapOS repository complete."
fi
pacman -S -y -y
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

pacman -Q | grep -q libpamac-full
if [ $? -eq 0 ]; then
    echo "Replacing Pacmac with bauh..."
    # Do not remove dependencies to keep 'flatpak' and 'snapd' installed.
    # The first '--nodeps' tells Pacman to not remove dependencies.
    # The second '--nodeps' tells is to ignore the packages being required as a dependency for other applications.
    # 'discover' needs 'archlinux-appstream-data' so we will re-install it after this.
    pacman -R -n --nodeps --nodeps --noconfirm archlinux-appstream-data-pamac libpamac-full pamac-all
    ${CMD_PACMAN_INSTALL} archlinux-appstream-data
    ${CMD_YAY_INSTALL} bauh
    rm -f /home/winesap/Desktop/org.manjaro.pamac.manager.desktop
    cp /usr/share/applications/bauh.desktop /home/winesap/Desktop/
    chmod +x /home/winesap/Desktop/bauh.desktop
    chown winesap.winesap /home/winesap/Desktop/bauh.desktop
    # Enable the 'snapd' service. This was not enabled in winesapOS <= 3.1.1.
    systemctl enable --now snapd
    echo "Replacing Pacmac with bauh complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

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
crudini --del /etc/pacman.conf community
crudini --set /etc/pacman.conf multilib Server 'https://mirror.rackspace.com/archlinux/$repo/os/$arch'
crudini --del /etc/pacman.conf multilib Include
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
pacman -S -y -y
# Manually upgrade Pacman to ensure that it can handle the merging of the [community] repository into the [extra] repository.
# https://github.com/LukeShortCloud/winesapOS/issues/589
pacman -S -y --noconfirm "pacman>=6.0.2-7"
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    pacman --noconfirm -S archlinux-keyring manjaro-keyring
else
    pacman --noconfirm -S archlinux-keyring
fi
echo "Enabling newer upstream Arch Linux package repositories complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

# Install ProtonUp-Qt as a Flatpak to avoid package conflicts when upgrading to Arch Linux packages.
# https://github.com/LukeShortCloud/winesapOS/issues/375#issuecomment-1146678638
pacman -Q | grep -q protonup-qt
if [ $? -eq 0 ]; then
    echo "Installing a newer version of ProtonUp-Qt..."
    pacman -R -n -s --noconfirm protonup-qt
    rm -f /home/winesap/Desktop/net.davidotek.pupgui2.desktop
    ${CMD_FLATPAK_INSTALL} net.davidotek.pupgui2
    cp /var/lib/flatpak/app/net.davidotek.pupgui2/current/active/export/share/applications/net.davidotek.pupgui2.desktop /home/winesap/Desktop/
    chmod +x /home/winesap/Desktop/net.davidotek.pupgui2.desktop
    chown winesap.winesap /home/winesap/Desktop/net.davidotek.pupgui2.desktop
    echo "Installing a newer version of ProtonUp-Qt complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

flatpak list | grep -P "^AntiMicroX" &> /dev/null
if [ $? -ne 0 ]; then
    echo "Installing AntiMicroX for changing controller inputs..."
    ${CMD_FLATPAK_INSTALL} io.github.antimicrox.antimicrox
    cp /var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop /home/winesap/Desktop/
    chmod +x /home/winesap/Desktop/io.github.antimicrox.antimicrox.desktop
    chown winesap.winesap /home/winesap/Desktop/io.github.antimicrox.antimicrox.desktop
    echo "Installing AntiMicroX for changing controller inputs complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

pacman -Q | grep -q linux-firmware-neptune
if [ $? -eq 0 ]; then
    echo "Removing conflicting 'linux-firmware-neptune' packages..."
    pacman -Q linux-firmware-neptune &> /dev/null
    if [ $? -eq 0 ]; then
        pacman -R -n -s --noconfirm linux-firmware-neptune
    fi
    pacman -Q linux-firmware-neptune-rtw-debug &> /dev/null
    if [ $? -eq 0 ]; then
        pacman -R -n -s --noconfirm linux-firmware-neptune-rtw-debug
    fi
    ${CMD_PACMAN_INSTALL} linux-firmware
    echo "Removing conflicting 'linux-firmware-neptune' packages complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9

pacman -Q | grep -q mesa-steamos
if [ $? -ne 0 ]; then
    echo "Upgrading to a customized Mesa package from SteamOS with better cross-platform driver support..."
    # Remove conflicting packages first.
    pacman -R -n -s --noconfirm libva-mesa-driver mesa-vdpau opencl-mesa lib32-libva-mesa-driver lib32-mesa-vdpau lib32-opencl-mesa
    # Install without '--noconfirm' to get prompts if we want to replace resolved conflicts.
    yes | pacman -S --needed \
      winesapos/mesa-steamos \
      winesapos/libva-mesa-driver-steamos \
      winesapos/mesa-vdpau-steamos \
      winesapos/opencl-mesa-steamos \
      winesapos/vulkan-intel-steamos \
      winesapos/vulkan-mesa-layers-steamos \
      winesapos/vulkan-radeon-steamos \
      winesapos/vulkan-swrast-steamos \
      winesapos/lib32-mesa-steamos \
      winesapos/lib32-libva-mesa-driver-steamos \
      winesapos/lib32-mesa-vdpau-steamos \
      winesapos/lib32-opencl-mesa-steamos \
      winesapos/lib32-vulkan-intel-steamos \
      winesapos/lib32-vulkan-mesa-layers-steamos \
      winesapos/lib32-vulkan-radeon-steamos \
      winesapos/lib32-vulkan-swrast-steamos
    echo "Upgrading to a customized Mesa package from SteamOS with better cross-platform driver support complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 10

echo "Upgrading to 'clang' from Arch Linux..."
pacman -Q | grep -q clang-libs
if [ $? -eq 0 ]; then
    # SteamOS 3 splits 'clang' (64-bit) into two packages: (1) 'clang' and (2) 'clang-libs'.
    # It does not ship a 'lib32-clang' package.
    pacman -R -d --nodeps --noconfirm clang clang-libs
fi
# Arch Linux has a 'clang' and 'lib32-clang' package.
${CMD_PACMAN_INSTALL} clang lib32-clang
echo "Upgrading to 'clang' from Arch Linux complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 11

echo "Running 3.0.1 to 3.1.0 upgrades complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.1.0 to 3.1.1 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.1.0 to 3.1.1 upgrades..." 2 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

pacman -Q | grep -q pipewire-media-session
if [ $? -eq 0 ]; then
    pacman -R -d --nodeps --noconfirm pipewire-media-session
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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.1.1 to 3.2.0 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.1.1 to 3.2.0 upgrades..." 7 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

pacman -Q | grep -q linux-steamos
if [ $? -ne 0 ]; then
    pacman -R -d --nodeps --noconfirm linux-neptune linux-neptune-headers
    ${CMD_PACMAN_INSTALL} linux-steamos linux-steamos-headers
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

flatpak list | grep -P "^Flatseal" &> /dev/null
if [ $? -ne 0 ]; then
    ${CMD_FLATPAK_INSTALL} com.github.tchx84.Flatseal
    cp /var/lib/flatpak/app/com.github.tchx84.Flatseal/current/active/export/share/applications/com.github.tchx84.Flatseal.desktop /home/winesap/Desktop/
    chmod +x /home/winesap/Desktop/com.github.tchx84.Flatseal.desktop
    chown winesap.winesap /home/winesap/Desktop/com.github.tchx84.Flatseal.desktop
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

pacman -Q | grep -q game-devices-udev
if [ $? -eq 0 ]; then
    sudo -u winesap yay --noconfirm -S --removemake game-devices-udev
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

pacman -Q | grep -q broadcom-wl-dkms
if [ $? -ne 0 ]; then
    echo -e "\nblacklist b43\nblacklist b43legacy\nblacklist bcm43xx\nblacklist bcma\nblacklist brcm80211\nblacklist brcmsmac\nblacklist brcmfmac\nblacklist brcmutil\nblacklist ndiswrapper\nblacklist ssb\nblacklist tg3\n" > /etc/modprobe.d/winesapos.conf
    ${CMD_PACMAN_INSTALL} broadcom-wl-dkms
    echo "wl" >> /etc/modules-load.d/winesapos-wifi.conf
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

pacman -Q | grep -q mbpfan-git
if [ $? -ne 0 ]; then
    ${CMD_YAY_INSTALL} mbpfan-git
    crudini --set /etc/mbpfan.conf general min_fan_speed 1300
    crudini --set /etc/mbpfan.conf general max_fan_speed 6200
    crudini --set /etc/mbpfan.conf general max_temp 105
    systemctl enable --now mbpfan
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

# If holo-rel/filesystem is replaced by core/filesystem during an upgrade it can break UEFI boot.
# https://github.com/LukeShortCloud/winesapOS/issues/514
grep -P ^IgnorePkg /etc/pacman.conf  | grep -q filesystem
if [ $? -ne 0 ]; then
    echo "Ignoring the conflicting 'filesystem' package..."
    sed -i s'/IgnorePkg = /IgnorePkg = filesystem /'g /etc/pacman.conf
    echo "Ignoring the conflicting 'filesystem' package complete."
fi
echo "Running 3.1.1 to 3.2.0 upgrades complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

echo "Running 3.2.0 to 3.2.1 upgrades..."
echo "Switching Steam back to the 'stable' update channel..."
rm -f /home/winesap/.local/share/Steam/package/beta
echo "Switching Steam back to the 'stable' update channel complete."
echo "Running 3.2.0 to 3.2.1 upgrades complete."

echo "Running 3.2.1 to 3.3.0 upgrades..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Running 3.2.1 to 3.3.0 upgrades..." 6 | cut -d" " -f1)
echo "Setting up default text editor..."
grep -q "EDITOR=nano" /etc/environment
if [ $? -eq 0 ]; then
    echo "Default text editor already set. Skipping..."
else
    echo "Default text editor not already set. Proceeding..."
    echo "EDITOR=nano" >> /etc/environment
fi
echo "Setting up default text editor complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

echo "Switching to the new 'vapor-steamos-theme-kde' package..."
pacman -Q steamdeck-kde-presets
if [ $? -eq 0 ]; then
    echo "Old 'steamdeck-kde-presets' package detected. Proceeding..."
    rm -f /usr/share/libalpm/hooks/steamdeck-kde-presets.hook
    pacman -R -n --noconfirm steamdeck-kde-presets
    ${CMD_YAY_INSTALL} vapor-steamos-theme-kde
    # Force update "konsole" to get the /etc/xdg/konsolerc file it provides.
    pacman -S --noconfirm konsole
    crudini --set /etc/xdg/konsolerc "Desktop Entry" DefaultProfile Vapor.profile
    # Remove the whitespace from the lines that 'crudini' creates.
    sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" ${WINESAPOS_INSTALL_DIR}/etc/xdg/konsolerc
else
    echo "Old 'steamdeck-kde-presets' package not detected. Skipping..."
fi
echo "Switching to the new 'vapor-steamos-theme-kde' package complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

echo "Switching to the new 'libpipewire' package..."
pacman -Q pipewire
if [ $? -eq 0 ]; then
    echo "Old 'pipewire' package detected. Proceeding..."
    pacman -R -n --nodeps --nodeps --noconfirm pipewire lib32-pipewire
    ${CMD_PACMAN_INSTALL} libpipewire lib32-libpipewire
else
    echo "Old 'pipewire' package not detected. Skipping..."
fi
echo "Switching to the new 'libpipewire' package complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3

echo "Adding Pacman support to Discover..."
${CMD_PACMAN_INSTALL} packagekit-qt5
echo "Adding Pacman support to Discover complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4

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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

echo "Setting 'iwd' as the backend for NetworkManager..."
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf
systemctl stop NetworkManager
systemctl disable --now wpa_supplicant
systemctl enable --now iwd
systemctl start NetworkManager
echo "Setting 'iwd' as the backend for NetworkManager complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
echo "Running 3.2.1 to 3.3.0 upgrades complete."

echo "Upgrading system packages..."
kdialog_dbus=$(sudo -E -u winesap kdialog --title "winesapOS Upgrade" --progressbar "Please wait for all system packages to upgrade (this can take a long time)..." 9 | cut -d" " -f1)
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
# The 'base-devel' package needs to be explicitly updated since it was changed to a meta package.
# https://github.com/LukeShortCloud/winesapOS/issues/569
pacman -S -y --noconfirm base-devel

# This upgrade needs to happen before updating the Linux kernels.
# Otherwise, it can lead to an unbootable system.
# https://github.com/LukeShortCloud/winesapOS/issues/379#issuecomment-1166577683
pacman -S -y -y -u --noconfirm
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

flatpak update -y --noninteractive
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
# Remove the Flatpak directory for the user to avoid errors.
# This directory will automatically get re-generated when a 'flatpak' command is ran.
# https://github.com/LukeShortCloud/winesapOS/issues/516
rm -r -f /home/winesap/.local/share/flatpak

sudo -u winesap yay -S -y -y -u --noconfirm
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
echo "Upgrading system packages complete."

echo "Upgrading ignored packages..."
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]]; then
    yes | pacman -S core/linux-lts core/linux-lts-headers kernel-lts/linux-lts510 kernel-lts/linux-lts510-headers core/grub holo-rel/filesystem
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    yes | pacman -S core/linux515 core/linux515-headers core/linux510 core/linux510-headers core/grub holo-rel/filesystem
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
    yes | pacman -S core/linux-lts core/linux-lts-headers linux-steamos linux-steamos-headers core/grub holo-rel/filesystem
fi
echo "Upgrading ignored packages done."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5

pacman -Q | grep -q nvidia-dkms
if [ $? -eq 0 ]; then
    echo "Upgrading NVIDIA drivers..."
    pacman -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia
    echo "Upgrading NVIDIA drivers complete."
fi
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6

dmidecode -s system-product-name | grep -P ^Mac
if [ $? -eq 0 ]; then
    echo "Mac hardware detected."
    echo "Re-installing Mac drivers..."
    # Sound driver for Linux 5.15.
    # https://github.com/LukeShortCloud/winesapOS/issues/152
    git clone https://github.com/egorenar/snd-hda-codec-cs8409.git
    cd snd-hda-codec-cs8409
    # The last kernel found from the 'tail' command is actually the newest one.
    export KVER=$(ls -1 /lib/modules/ | grep -P "^5.15" | tail -n 1)
    make
    make install
    cd ..
    rm -rf snd-hda-codec-cs8409
    # Reinstall the MacBook Pro Touch Bar driver to force the DKMS to re-install on all kernels.
    sudo -u winesap yay --noconfirm -S --removemake macbook12-spi-driver-dkms
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
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7

echo "Rebuilding initramfs with new drivers..."
mkinitcpio -P
echo "Rebuilding initramfs with new drivers complete."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8

echo "Updating Btrfs snapshots in the GRUB menu..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "Updating Btrfs snapshots in the GRUB menu complete."

echo "Enabling Flatpaks to update upon reboot for NVIDIA systems..."
ls /etc/systemd/system/winesapos-flatpak-update.service
if [ $? -ne 0 ]; then
    sudo curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/winesapos-flatpak-update.service -L -o /etc/systemd/system/winesapos-flatpak-update.service
    sudo systemctl daemon-reload
fi
sudo systemctl enable winesapos-flatpak-update.service
echo "Enabling Flatpaks to update upon reboot for NVIDIA systems complete."

echo "VERSION_ORIGINAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
sudo -E -u winesap ${qdbus_cmd} ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
echo "End time: $(date --iso-8601=seconds)"
