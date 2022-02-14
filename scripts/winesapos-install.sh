#!/bin/zsh

if [[ "${WINESAPOS_DEBUG}" == "true" ]]; then
    set -x
fi

# Log both the standard output and error from this script to a log file.
exec > >(tee /tmp/winesapos-install.log) 2>&1
echo "Start time: $(date)"

WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-arch}"
WINESAPOS_DE="${WINESAPOS_DE:-kde}"
WINESAPOS_ENCRYPT="${WINESAPOS_ENCRYPT:-false}"
WINESAPOS_ENCRYPT_PASSWORD="${WINESAPOS_ENCRYPT_PASSWORD:-password}"
WINESAPOS_LOCALE="${WINESAPOS_LOCALE:-en_US.UTF-8 UTF-8}"
WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
WINESAPOS_DISABLE_KERNEL_UPDATES="${WINESAPOS_DISABLE_KERNEL_UPDATES:-true}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
WINESAPOS_DEVICE="${WINESAPOS_DEVICE:-vda}"
DEVICE="/dev/${WINESAPOS_DEVICE}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u winesap yay --noconfirm -S)

lscpu | grep "Hypervisor vendor:"
if [ $? -ne 0 ]
then
    echo "This build is not running in a virtual machine. Exiting to be safe."
    exit 1
fi

echo "Creating partitions..."
# GPT is required for UEFI boot.
parted ${DEVICE} mklabel gpt
# An empty partition is required for BIOS boot backwards compatibility.
parted ${DEVICE} mkpart primary 2048s 2M
# exFAT partition for generic flash drive storage.
parted ${DEVICE} mkpart primary 2M 16G
# EFI partition.
parted ${DEVICE} mkpart primary fat32 16G 16.5G
parted ${DEVICE} set 3 boot on
parted ${DEVICE} set 3 esp on
# Boot partition.
parted ${DEVICE} mkpart primary ext4 16.5G 17.5G
# Root partition uses the rest of the space.
parted ${DEVICE} mkpart primary btrfs 17.5G 100%
# Formatting via 'parted' does not work so we need to reformat those partitions again.
mkfs -t exfat ${DEVICE}2
exfatlabel ${DEVICE}2 winesapos-drive
mkfs -t vfat ${DEVICE}3
# FAT32 file systems require upper-case labels that are 11 characters or shorter.
fatlabel ${DEVICE}3 WOS-EFI
mkfs -t ext4 ${DEVICE}4
e2label ${DEVICE}4 winesapos-boot

if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup -q luksFormat ${DEVICE}5
    cryptsetup config ${DEVICE}5 --label winesapos-luks
    echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup luksOpen ${DEVICE}5 cryptroot
    root_partition="/dev/mapper/cryptroot"
else
    root_partition="${DEVICE}5"
fi

mkfs -t btrfs ${root_partition}
btrfs filesystem label ${root_partition} winesapos-root
echo "Creating partitions complete."

echo "Mounting partitions..."
mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt
btrfs subvolume create /mnt/home
mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt/home
btrfs subvolume create /mnt/swap
mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt/swap
mkdir /mnt/boot
mount -t ext4 ${DEVICE}4 /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat ${DEVICE}3 /mnt/boot/efi

for i in tmp var/log var/tmp; do
    mkdir -p /mnt/${i}
    mount ramfs -t ramfs -o nodev,nosuid /mnt/${i}
done

echo "Mounting partitions complete."

echo "Configuring swap file..."
# Disable the usage of swap in the live media environment.
echo 0 > /proc/sys/vm/swappiness
touch /mnt/swap/swapfile
# Avoid Btrfs copy-on-write.
chattr +C /mnt/swap/swapfile
# Now fill in the 2 GiB swap file.
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=2000
# A swap file requires strict permissions to work.
chmod 0600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swaplabel --label winesapos-swap /mnt/swap/swapfile
swapon /mnt/swap/swapfile
echo "Configuring swap file complete."

echo "Setting up fastest pacman mirror on live media..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman-mirrors --api --protocol https --country United_States
    pacman -S -y --noconfirm
else
    pacman -S --needed --noconfirm reflector
    reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
    pacman -S -y --noconfirm
fi

echo "Setting up fastest pacman mirror on live media complete."

echo "Setting up Pacman parallel package downloads on live media..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g /etc/pacman.conf
echo "Setting up Pacman parallel package downloads on live media complete."

echo "Installing Arch Linux installation tools on the live media..."
# Required for the 'arch-chroot', 'genfstab', and 'pacstrap' tools.
# These are not provided by default in Manjaro.
/usr/bin/pacman --noconfirm -S --needed arch-install-scripts
echo "Installing Arch Linux installation tools on the live media complete."

echo "Installing ${WINESAPOS_DISTRO}..."
pacstrap -i /mnt base base-devel efibootmgr grub mkinitcpio networkmanager --noconfirm
arch-chroot /mnt systemctl enable NetworkManager systemd-timesyncd
sed -i s'/MODULES=(/MODULES=(btrfs\ /'g /mnt/etc/mkinitcpio.conf
echo "${WINESAPOS_LOCALE}" > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
# Example output: LANG=en_US.UTF-8
echo "LANG=$(echo ${WINESAPOS_LOCALE} | cut -d' ' -f1)" > /mnt/etc/locale.conf
echo "Installing ${WINESAPOS_DISTRO} complete."

echo "Setting up Pacman parallel package downloads in chroot..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g /mnt/etc/pacman.conf
echo "Setting up Pacman parallel package downloads in chroot complete."

echo "Saving partition mounts to /etc/fstab..."
partprobe
genfstab -L -P /mnt > /mnt/etc/fstab
echo "Saving partition mounts to /etc/fstab complete."

echo "Configuring fastest mirror in the chroot..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    cp ../files/pacman-mirrors.service /mnt/etc/systemd/system/
    # Enable on first boot.
    arch-chroot /mnt systemctl enable pacman-mirrors
    # This is required for 'pacman-mirrors' to determine if an IP address has been assigned yet.
    # Once an IP address is assigned, then the `pacman-mirrors' service will start.
    arch-chroot /mnt systemctl enable NetworkManager-wait-online.service
    # Temporarily set mirrors to United States to use during the build process.
    arch-chroot /mnt pacman-mirrors --api --protocol https --country United_States
else
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} reflector
    arch-chroot /mnt systemctl enable reflector.service
    arch-chroot /mnt reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
    arch-chroot /mnt pacman -S -y --noconfirm
fi

echo "Configuring fastest mirror in the chroot complete."

echo "Installing the 'yay' AUR package manager..."
arch-chroot /mnt ${CMD_PACMAN_INSTALL} curl tar
export YAY_VER="11.1.0"
curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
mv yay_${YAY_VER}_x86_64/yay /mnt/usr/bin/yay
rm -rf ./yay*
# Development packages required for building other packages.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} binutils dkms fakeroot gcc git make
echo "Installing the 'yay' AUR package manager complete."

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo "Installing AppArmor..."

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} apparmor apparmor-profiles
    else
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} apparmor
        arch-chroot /mnt ${CMD_YAY_INSTALL} krathalans-apparmor-profiles-git
    fi

    arch-chroot /mnt systemctl enable apparmor
    echo "Installing AppArmor complete."
fi

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} firewalld
fi

echo "Configuring user accounts..."
echo -e "root\nroot" | arch-chroot /mnt passwd root
arch-chroot /mnt useradd --create-home winesap
echo -e "winesap\nwinesap" | arch-chroot /mnt passwd winesap
echo "winesap ALL=(root) NOPASSWD:ALL" > /mnt/etc/sudoers.d/winesap
chmod 0440 /mnt/etc/sudoers.d/winesap
echo "Configuring user accounts complete."

echo "Installing 'crudini' from the AUR..."
# These packages have to be installed in this exact order.
# Dependency for 'python-iniparse'. Refer to: https://aur.archlinux.org/packages/python-iniparse/.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} python-tests
# Dependency for 'crudini'.
arch-chroot /mnt ${CMD_YAY_INSTALL} python-iniparse
arch-chroot /mnt ${CMD_YAY_INSTALL} crudini
echo "Installing 'crudini' from the AUR complete."

echo "Enabling 32-bit multlib libraries..."
arch-chroot /mnt crudini --set /etc/pacman.conf multilib Include /etc/pacman.d/mirrorlist
arch-chroot /mnt pacman -Sy
echo "Enabling 32-bit multlib libraries complete."

echo "Installing additional file system support..."
echo "APFS"
arch-chroot /mnt ${CMD_YAY_INSTALL} apfsprogs-git linux-apfs-rw-dkms-git
echo "Btrfs"
arch-chroot /mnt ${CMD_PACMAN_INSTALL} btrfs-progs
echo "ext3 and ext4"
arch-chroot /mnt ${CMD_PACMAN_INSTALL} e2fsprogs lib32-e2fsprogs
echo "exFAT"
arch-chroot /mnt ${CMD_PACMAN_INSTALL} exfatprogs
echo "FAT12, FAT16, and FAT32"
arch-chroot /mnt ${CMD_PACMAN_INSTALL} dosfstools
echo "HFS and HFS+"
arch-chroot /mnt ${CMD_YAY_INSTALL} hfsprogs
echo "NTFS"
arch-chroot /mnt ${CMD_PACMAN_INSTALL} ntfs-3g
echo "ZFS"
arch-chroot /mnt ${CMD_YAY_INSTALL} zfs-dkms zfs-utils
echo "Installing additional file system support complete."

echo "Installing sound drivers..."
# Install the PipeWire sound driver.
## PipeWire.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} pipewire lib32-pipewire pipewire-media-session
## PipeWire backwards compatibility.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} pipewire-alsa pipewire-jack lib32-pipewire-jack pipewire-pulse pipewire-v4l2 lib32-pipewire-v4l2
## Enable the required services.
## Manually create the 'systemctl --user enable' symlinks as the command does not work in a chroot.
mkdir -p /mnt/home/winesap/.config/systemd/user/default.target.wants/
arch-chroot /mnt ln -s /usr/lib/systemd/user/pipewire.service /home/winesap/.config/systemd/user/default.target.wants/pipewire.service
arch-chroot /mnt ln -s /usr/lib/systemd/user/pipewire-pulse.service /home/winesap/.config/systemd/user/default.target.wants/pipewire-pulse.service
# Custom systemd service to mute the audio on start.
# https://github.com/LukeShortCloud/winesapOS/issues/172
cp ../files/mute.service /mnt/etc/systemd/user/
arch-chroot /mnt ln -s /etc/systemd/user/mute.service /home/winesap/.config/systemd/user/default.target.wants/mute.service
# PulseAudio Control is a GUI used for managing PulseAudio (or, in our case, PipeWire-Pulse).
arch-chroot /mnt ${CMD_PACMAN_INSTALL} pavucontrol
echo "Installing sound drivers complete."

echo "Installing additional packages..."
arch-chroot /mnt ${CMD_PACMAN_INSTALL} clamav ffmpeg firefox jre8-openjdk libdvdcss libreoffice lm_sensors man-db mlocate nano ncdu nmap openssh python python-pip rsync shutter smartmontools sudo terminator tmate wget vim vlc zerotier-one zstd
# Download an offline database for ClamAV.
arch-chroot /mnt freshclam
echo "Installing additional packages complete."

echo "Installing additional packages from the AUR..."
arch-chroot /mnt ${CMD_YAY_INSTALL} google-chrome qdirstat
echo "Installing additional packages from the AUR complete."

echo "Installing Oh My Zsh..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} oh-my-zsh zsh
else
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} zsh
    arch-chroot /mnt ${CMD_YAY_INSTALL} oh-my-zsh-git
fi

cp /mnt/usr/share/oh-my-zsh/zshrc /mnt/home/winesap/.zshrc
chown 1000.1000 /mnt/home/winesap/.zshrc
echo "Installing Oh My Zsh complete."

echo "Installing the Linux kernels..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} linux510 linux510-headers linux515 linux515-headers
else
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} linux-lts linux-lts-headers
    # This repository contains binary/pre-built packages for Arch Linux LTS kernels.
    arch-chroot /mnt pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-key 76C6E477042BFE985CC220BD9C08A255442FAFF0
    arch-chroot /mnt pacman-key --lsign 76C6E477042BFE985CC220BD9C08A255442FAFF0
    arch-chroot /mnt crudini --set /etc/pacman.conf kernel-lts Server 'https://repo.m2x.dev/current/$repo/$arch'
    arch-chroot /mnt pacman -S -y --noconfirm
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} linux-lts510 linux-lts510-headers
fi

if [[ "${WINESAPOS_DISABLE_KERNEL_UPDATES}" == "true" ]]; then
    echo "Setting up Pacman to disable Linux kernel updates..."

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot /mnt crudini --set /etc/pacman.conf options IgnorePkg "linux515 linux515-headers linux510 linux510-headers"
    else
        arch-chroot /mnt crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-lts510 linux-lts510-headers"
    fi

    echo "Setting up Pacman to disable Linux kernel updates complete."
fi

arch-chroot /mnt ${CMD_PACMAN_INSTALL} linux-firmware
echo "Installing the Linux kernels complete."

echo "Optimizing battery life..."
arch-chroot /mnt ${CMD_YAY_INSTALL} auto-cpufreq
arch-chroot /mnt systemctl enable auto-cpufreq
echo "Optimizing battery life complete."

echo "Minimizing writes to the disk..."
arch-chroot /mnt crudini --set /etc/systemd/journald.conf Journal Storage volatile
echo "vm.swappiness=10" >> /mnt/etc/sysctl.d/00-winesapos.conf
echo "Minimizing writes to the disk compelete."

echo "Setting up the desktop environment..."
# Install Xorg.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} xorg-server lib32-mesa mesa xorg-server xorg-xinit xterm xf86-input-libinput xf86-video-amdgpu xf86-video-intel xf86-video-nouveau
# Install Light Display Manager.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} lightdm lightdm-gtk-greeter
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} lightdm-settings
else
    arch-chroot /mnt ${CMD_YAY_INSTALL} lightdm-settings
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    echo "Installing the Cinnamon desktop environment..."

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} cinnamon cinnamon-sounds cinnamon-wallpapers manjaro-cinnamon-settings manjaro-settings-manager
        # Install Manjaro specific Cinnamon theme packages.
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} adapta-maia-theme kvantum-manjaro
    else
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} cinnamon
    fi

    echo "Installing the Cinnamon desktop environment complete."
elif [[ "${WINESAPOS_DE}" == "kde" ]]; then
    echo "Installing the KDE Plasma desktop environment..."
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} plasma-meta plasma-nm

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} manjaro-kde-settings manjaro-settings-manager-kcm manjaro-settings-manager-knotifier
        # Install Manjaro specific KDE Plasma theme packages.
        arch-chroot /mnt ${CMD_PACMAN_INSTALL} breath-classic-icon-themes breath-wallpapers plasma5-themes-breath sddm-breath-theme
    fi

    echo "Installing the KDE Plasma desktop environment complete."
fi

# Start LightDM. This will provide an option of which desktop environment to load.
arch-chroot /mnt systemctl enable lightdm
# Install Bluetooth.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} blueberry
# Install webcam software.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} cheese
## This is required to turn Bluetooth on or off.
arch-chroot /mnt usermod -a -G rfkill winesap
# Install printer drivers.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} cups libcups lib32-libcups bluez-cups cups-pdf usbutils
arch-chroot /mnt systemctl enable cups
echo "Setting up the desktop environment complete."

echo 'Setting up the "pamac" package manager...'
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} pamac-gtk pamac-cli libpamac-flatpak-plugin libpamac-snap-plugin
else
    # This package needs to be manually removed first as 'pamac-all' will
    # install a conflicting package called 'archlinux-appstream-data-pamac'.
    # The KDE Plasma package 'discover' depends on 'archlinux-appstream-data'.
    arch-chroot /mnt pacman --noconfirm -Rd --nodeps archlinux-appstream-data
    arch-chroot /mnt ${CMD_YAY_INSTALL} pamac-all
fi
echo "Setting up the 'pamac' package manager complete."

echo "Installing gaming tools..."
# Vulkan drivers.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} vulkan-intel lib32-vulkan-intel vulkan-radeon lib32-vulkan-radeon
# GameMode.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} gamemode lib32-gamemode
# MultiMC for Minecraft.
arch-chroot /mnt ${CMD_YAY_INSTALL} multimc-bin
# Lutris.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} lutris
# Heoric Games Launcher (for Epic Games Store games).
arch-chroot /mnt ${CMD_YAY_INSTALL} heroic-games-launcher-bin
# Steam.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} steam-manjaro steam-native
else
    arch-chroot /mnt ${CMD_PACMAN_INSTALL} steam steam-native-runtime
fi
# Wine.
arch-chroot /mnt ${CMD_PACMAN_INSTALL} wine-staging winetricks alsa-lib alsa-plugins cups dosbox giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 vkd3d vulkan-icd-loader wine_gecko wine-mono
# protontricks. 'wine-staging' is installed first because otherwise 'protontricks' depends on 'winetricks' which depends on 'wine' by default.
arch-chroot /mnt ${CMD_YAY_INSTALL} protontricks
# Proton GE for Steam.
curl https://raw.githubusercontent.com/toazd/ge-install-manager/master/ge-install-manager --location --output /mnt/usr/local/bin/ge-install-manager
chmod +x /mnt/usr/local/bin/ge-install-manager
# The '/tmp/' directory will not work as a 'tmp_path' for 'ge-install-manager' due to a
# bug relating to calculating storage space on ephemeral file systems. As a workaround,
# we use '/home/winesap/tmp' as the temporary path.
# https://github.com/toazd/ge-install-manager/issues/3
mkdir -p /mnt/home/winesap/tmp /mnt/home/winesap/.config/ge-install-manager/ /mnt/home/winesap/.local/share/Steam/compatibilitytools.d/
cp ../files/ge-install-manager.conf /mnt/home/winesap/.config/ge-install-manager/
chown -R 1000.1000 /mnt/home/winesap
arch-chroot /mnt sudo -u winesap ge-install-manager -i Proton-6.5-GE-2
rm -f /mnt/home/winesap/.local/share/Steam/compatibilitytools.d/Proton-*.tar.gz
echo "Installing gaming tools complete."

echo "Setting up desktop shortcuts..."
mkdir /mnt/home/winesap/Desktop
cp /mnt/usr/share/applications/multimc.desktop /mnt/home/winesap/Desktop/
sed -i s'/Exec=multimc/Exec=\/usr\/bin\/gamemoderun\ multimc/'g /mnt/home/winesap/Desktop/multimc.desktop
arch-chroot /mnt crudini --set /home/winesap/Desktop/multimc.desktop "Desktop Entry" Name "MultiMC - GameMode"
cp /mnt/usr/share/applications/heroic.desktop /mnt/home/winesap/Desktop/heroic_games_launcher.desktop
sed -i s'/Exec=\/opt\/Heroic\/heroic\ \%U/Exec=\/usr\/bin\/gamemoderun \/opt\/Heroic\/heroic\ \%U/'g /mnt/home/winesap/Desktop/heroic_games_launcher.desktop
arch-chroot /mnt crudini --set /home/winesap/Desktop/heroic_games_launcher.desktop "Desktop Entry" Name "Heroic Games Launcher - GameMode"
cp /mnt/usr/share/applications/net.lutris.Lutris.desktop /mnt/home/winesap/Desktop/lutris.desktop
sed -i s'/Exec=lutris\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/lutris\ \%U/'g /mnt/home/winesap/Desktop/lutris.desktop
arch-chroot /mnt crudini --set /home/winesap/Desktop/lutris.desktop "Desktop Entry" Name "Lutris - GameMode"
cp /mnt/usr/share/applications/steam-native.desktop /mnt/home/winesap/Desktop/steam_native.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-native\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam\-native\ \%U/'g /mnt/home/winesap/Desktop/steam_native.desktop
arch-chroot /mnt crudini --set /home/winesap/Desktop/steam_native.desktop "Desktop Entry" Name "Steam (Native) - GameMode"
cp /mnt/usr/share/applications/steam.desktop /mnt/home/winesap/Desktop/steam_runtime.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam-runtime\ \%U/'g /mnt/home/winesap/Desktop/steam_runtime.desktop
arch-chroot /mnt crudini --set /home/winesap/Desktop/steam_runtime.desktop "Desktop Entry" Name "Steam (Runtime) - GameMode"
cp /mnt/usr/lib/libreoffice/share/xdg/startcenter.desktop /mnt/home/winesap/Desktop/libreoffice-startcenter.desktop
cp /mnt/usr/share/applications/google-chrome.desktop /mnt/home/winesap/Desktop/
cp /mnt/usr/share/applications/qdirstat.desktop /mnt/home/winesap/Desktop/
cp /mnt/usr/share/applications/org.manjaro.pamac.manager.desktop /mnt/home/winesap/Desktop/
# Fix permissions on the desktop shortcuts.
chmod +x /mnt/home/winesap/Desktop/*.desktop
chown -R 1000.1000 /mnt/home/winesap/Desktop
echo "Setting up desktop shortcuts complete."

echo "Setting up Mac drivers..."
# Sound driver.
arch-chroot /mnt git clone https://github.com/LukeShortCloud/snd_hda_macbookpro.git -b mac-linux-gaming-stick
arch-chroot /mnt /bin/zsh snd_hda_macbookpro/install.cirrus.driver.sh
echo "snd-hda-codec-cirrus" >> /mnt/etc/modules-load.d/winesapos.conf
# MacBook Pro touchbar driver.
arch-chroot /mnt ${CMD_YAY_INSTALL} macbook12-spi-driver-dkms
sed -i s'/MODULES=(/MODULES=(applespi spi_pxa2xx_platform intel_lpss_pci apple_ibridge apple_ib_tb apple_ib_als /'g /mnt/etc/mkinitcpio.conf
# iOS device management via 'usbmuxd' and a workaround required for the Touch Bar to continue to work.
# 'uxbmuxd' and MacBook Pro Touch Bar bug reports:
# https://github.com/libimobiledevice/usbmuxd/issues/138
# https://github.com/roadrunner2/macbook12-spi-driver/issues/42
cp ../files/touch-bar-usbmuxd-fix.service /mnt/etc/systemd/system/
arch-chroot /mnt systemctl enable touch-bar-usbmuxd-fix
# MacBook Pro >= 2018 require a special T2 Linux driver for the keyboard and mouse to work.
arch-chroot /mnt git clone https://github.com/LukeShortCloud/mbp2018-bridge-drv --branch mac-linux-gaming-stick /usr/src/apple-bce-0.1

for kernel in $(ls -1 /mnt/usr/lib/modules/ | grep -P "^[0-9]+"); do
    # This will sometimes fail the first time it tries to install.
    arch-chroot /mnt timeout 120s dkms install -m apple-bce -v 0.1 -k ${kernel}

    if [ $? -ne 0 ]; then
        arch-chroot /mnt dkms install -m apple-bce -v 0.1 -k ${kernel}
    fi

done

sed -i s'/MODULES=(/MODULES=(apple-bce /'g /mnt/etc/mkinitcpio.conf
# Blacklist Mac WiFi drivers are these are known to be unreliable.
echo -e "\nblacklist brcmfmac\nblacklist brcmutil" >> /mnt/etc/modprobe.d/winesapos.conf
echo "Setting up Mac drivers complete."

echo "Setting mkinitcpio modules and hooks order..."

# Required fix for:
# https://github.com/LukeShortCloud/winesapos/issues/94
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    # Also add 'keymap' and 'encrypt' for LUKS encryption support.
    sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)/'g /mnt/etc/mkinitcpio.conf
else
    sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)/'g /mnt/etc/mkinitcpio.conf
fi

echo "Setting mkinitcpio modules and hooks order complete."

echo "Setting up the bootloader..."
arch-chroot /mnt mkinitcpio -p linux510 -p linux515
# These two configuration lines allow the GRUB menu to show on boot.
# https://github.com/LukeShortCloud/winesapos/issues/41
sed -i s'/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/'g /mnt/etc/default/grub
sed -i s'/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/'g /mnt/etc/default/grub

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo "Enabling AppArmor in the Linux kernel..."
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor /'g /mnt/etc/default/grub
    echo "Enabling AppArmor in the Linux kernel complete."
fi

if [[ "${WINESAPOS_CPU_MITIGATIONS}" == "false" ]]; then
    echo "Enabling Linux kernel-level CPU exploit mitigations..."
    sed -i s'/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mitigations=off /'g /mnt/etc/default/grub
    echo "Enabling Linux kernel-level CPU exploit mitigations done."
fi

# Enable Btrfs with zstd compression support.
# This will help allow GRUB to save the selected kernel for the next boot.
sed -i s'/GRUB_PRELOAD_MODULES="/GRUB_PRELOAD_MODULES="btrfs zstd /'g /mnt/etc/default/grub
# Disable the submenu to show all boot kernels/options on the main GRUB menu.
arch-chroot /mnt crudini --set /etc/default/grub "" GRUB_DISABLE_SUBMENU y
# Remove the whitespace from the 'GRUB_DISABLE_SUBMENU = y' line that 'crudini creates.
sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" /mnt/etc/default/grub

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS --removable
parted ${DEVICE} set 1 bios_grub on
arch-chroot /mnt grub-install --target=i386-pc ${DEVICE}

if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="cryptdevice=LABEL=winesapos-luks:cryptroot root='$(echo ${root_partition} | sed -e s'/\//\\\//'g)' /'g /mnt/etc/default/grub
fi

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo "Setting up the bootloader complete."

echo "Setting up root file system resize script..."
# This package provides the required 'growpart' command.
arch-chroot /mnt ${CMD_YAY_INSTALL} cloud-guest-utils
# Copy from the current directory which should be "scripts".
cp resize-root-file-system.sh /mnt/usr/local/bin/
cp ../files/resize-root-file-system.service /mnt/etc/systemd/system/
arch-chroot /mnt systemctl enable resize-root-file-system
echo "Setting up root file system resize script complete."

echo "Configuring Btrfs backup tools..."
arch-chroot /mnt ${CMD_PACMAN_INSTALL} grub-btrfs snapper snap-pac
cp ../files/etc-snapper-configs-root /mnt/etc/snapper/configs/root
cp ../files/etc-snapper-configs-root /mnt/etc/snapper/configs/home
sed -i s'/SUBVOLUME=.*/SUBVOLUME=\"\/home\"/'g /mnt/etc/snapper/configs/home
arch-chroot /mnt chown -R root.root /etc/snapper/configs
btrfs subvolume create /mnt/.snapshots
btrfs subvolume create /mnt/home/.snapshots
# Ensure the new "root" and "home" configurations will be loaded.
sed -i s'/SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"root home\"/'g /mnt/etc/conf.d/snapper
arch-chroot /mnt systemctl enable snapper-timeline.timer snapper-cleanup.timer
echo "Configuring Btrfs backup tools complete."

echo "Resetting the machine-id file..."
echo -n | tee /mnt/etc/machine-id
rm -f /mnt/var/lib/dbus/machine-id
arch-chroot /mnt ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Resetting the machine-id file complete."

echo "Setting up winesapOS files..."
mkdir /mnt/etc/winesapos/
cp ../VERSION /mnt/etc/winesapos/
cp /tmp/winesapos-install.log /mnt/etc/winesapos/
# Continue to log to the file after it has been copied over.
exec > >(tee -a /mnt/etc/winesapos/winesapos-install.log) 2>&1
echo "Setting up winesapOS files complete."

echo "Cleaning up and syncing files to disk..."
chown -R 1000.1000 /mnt/home/winesap
arch-chroot /mnt pacman --noconfirm -S -c -c
rm -rf /mnt/var/cache/pacman/pkg/* /mnt/home/winesap/.cache/yay/*
sync
echo "Cleaning up and syncing files to disk complete."

if [[ "${WINESAPOS_PASSWD_EXPIRE}" == "true" ]]; then

    for u in root winesap; do
        echo -n "Setting the password for ${u} to expire..."
        arch-chroot /mnt passwd --expire ${u}
        echo "Done."
    done

fi

echo "Running tests..."
zsh ./winesapos-tests.sh
echo "Running tests complete."

echo "Done."
echo "End time: $(date)"
