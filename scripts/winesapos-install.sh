#!/bin/zsh

WINESAPOS_DEBUG_INSTALL="${WINESAPOS_DEBUG_INSTALL:-true}"
if [[ "${WINESAPOS_DEBUG_INSTALL}" == "true" ]]; then
    set -x
else
    set +x
fi

# Log both the standard output and error from this script to a log file.
exec > >(tee /tmp/winesapos-install.log) 2>&1
echo "Start time: $(date)"

WINESAPOS_INSTALL_DIR="${WINESAPOS_INSTALL_DIR:-/winesapos}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-steamos}"
WINESAPOS_DE="${WINESAPOS_DE:-plasma}"
WINESAPOS_ENCRYPT="${WINESAPOS_ENCRYPT:-false}"
WINESAPOS_ENCRYPT_PASSWORD="${WINESAPOS_ENCRYPT_PASSWORD:-password}"
WINESAPOS_LOCALE="${WINESAPOS_LOCALE:-en_US.UTF-8 UTF-8}"
WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
WINESAPOS_DISABLE_KERNEL_UPDATES="${WINESAPOS_DISABLE_KERNEL_UPDATES:-true}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
WINESAPOS_SUDO_NO_PASSWORD="${WINESAPOS_SUDO_NO_PASSWORD:-true}"
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

clear_cache() {
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman --noconfirm -S -c -c
    rm -rf ${WINESAPOS_INSTALL_DIR}/var/cache/pacman/pkg/* ${WINESAPOS_INSTALL_DIR}/home/winesap/.cache/yay/*
}

echo "Creating partitions..."
# GPT is required for UEFI boot.
parted ${DEVICE} mklabel gpt
# An empty partition is required for BIOS boot backwards compatibility.
parted ${DEVICE} mkpart primary 2048s 2M
# exFAT partition for generic flash drive storage.
parted ${DEVICE} mkpart primary 2M 16G
## Configure this partition to be automatically mounted on Windows.
parted ${DEVICE} set 2 msftdata on
# EFI partition.
parted ${DEVICE} mkpart primary fat32 16G 16.5G
parted ${DEVICE} set 3 boot on
parted ${DEVICE} set 3 esp on
# Boot partition.
parted ${DEVICE} mkpart primary ext4 16.5G 17.5G
# Root partition uses the rest of the space.
parted ${DEVICE} mkpart primary btrfs 17.5G 100%
# Avoid a race-condition where formatting devices may happen before the system detects the new partitions.
sync
partprobe
# Formatting via 'parted' does not work so we need to reformat those partitions again.
mkfs -t exfat ${DEVICE}2
# exFAT file systems require labels that are 11 characters or shorter.
exfatlabel ${DEVICE}2 wos-drive
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
mkdir -p ${WINESAPOS_INSTALL_DIR}
mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}
btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/home
mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}/home
btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/swap
mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}/swap
mkdir ${WINESAPOS_INSTALL_DIR}/boot
mount -t ext4 ${DEVICE}4 ${WINESAPOS_INSTALL_DIR}/boot

# On SteamOS 3, the package 'holo/filesystem' creates the directory '/efi' and a symlink from '/boot/efi' to it.
if [[ "${WINESAPOS_DISTRO}" != "steamos" ]]; then
    mkdir ${WINESAPOS_INSTALL_DIR}/boot/efi
    mount -t vfat ${DEVICE}3 ${WINESAPOS_INSTALL_DIR}/boot/efi
fi

for i in tmp var/log var/tmp; do
    mkdir -p ${WINESAPOS_INSTALL_DIR}/${i}
    mount ramfs -t ramfs -o nodev,nosuid ${WINESAPOS_INSTALL_DIR}/${i}
done

echo "Mounting partitions complete."

echo "Setting up fastest pacman mirror on live media..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    pacman-mirrors --api --protocol https --country United_States
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    pacman -S --needed --noconfirm reflector
    reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
fi

pacman -S -y --noconfirm
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

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    pacstrap -i ${WINESAPOS_INSTALL_DIR} holo/filesystem base base-devel --noconfirm
    # After the 'holo/filesystem' package has been installed,
    # we can mount the UEFI file system.
    mount -t vfat ${DEVICE}3 ${WINESAPOS_INSTALL_DIR}/efi
    rm -f ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    cp ../files/etc-pacman.conf_steamos ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y -y
else
    pacstrap -i ${WINESAPOS_INSTALL_DIR} base base-devel --noconfirm
fi

# Avoid installing the 'grub' package from SteamOS repositories as it is missing the '/usr/bin/grub-install' binary.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} efibootmgr core/grub mkinitcpio networkmanager
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable NetworkManager systemd-timesyncd
sed -i s'/MODULES=(/MODULES=(btrfs\ /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
echo "${WINESAPOS_LOCALE}" >> ${WINESAPOS_INSTALL_DIR}/etc/locale.gen
arch-chroot ${WINESAPOS_INSTALL_DIR} locale-gen
# Example output: LANG=en_US.UTF-8
echo "LANG=$(echo ${WINESAPOS_LOCALE} | cut -d' ' -f1)" > ${WINESAPOS_INSTALL_DIR}/etc/locale.conf
# Hostname.
echo winesapos > ${WINESAPOS_INSTALL_DIR}/etc/hostname
## This is not a typo. The IPv4 address should '127.0.1.1' instead of '127.0.0.1' to work with systemd.
echo "127.0.1.1    winesapos" >> ${WINESAPOS_INSTALL_DIR}/etc/hosts
## This package provides the 'hostname' command along with other useful network utilities.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} inetutils
echo "Installing ${WINESAPOS_DISTRO} complete."

echo "Setting up Pacman parallel package downloads in chroot..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
echo "Setting up Pacman parallel package downloads in chroot complete."

echo "Saving partition mounts to /etc/fstab..."
sync
partprobe
# Force a rescan of labels on the system.
# https://github.com/LukeShortCloud/winesapOS/issues/251
systemctl restart systemd-udev-trigger
sleep 5s
# On SteamOS 3, '/home/swapfile' gets picked up by the 'genfstab' command.
genfstab -L -P ${WINESAPOS_INSTALL_DIR} | grep -v '/home/swapfile' > ${WINESAPOS_INSTALL_DIR}/etc/fstab
# Manually add the swap file since it is not used.
echo "/swap/swapfile    none    swap    defaults    0 0" >> ${WINESAPOS_INSTALL_DIR}/etc/fstab
echo "Saving partition mounts to /etc/fstab complete."

echo "Configuring fastest mirror in the chroot..."

# Not required for SteamOS because there is only one mirror and it already uses a CDN.
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    cp ../files/pacman-mirrors.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
    # Enable on first boot.
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable pacman-mirrors
    # This is required for 'pacman-mirrors' to determine if an IP address has been assigned yet.
    # Once an IP address is assigned, then the `pacman-mirrors' service will start.
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable NetworkManager-wait-online.service
    # Temporarily set mirrors to United States to use during the build process.
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-mirrors --api --protocol https --country United_States
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} reflector
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable reflector.service
    arch-chroot ${WINESAPOS_INSTALL_DIR} reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y --noconfirm
fi

echo "Configuring fastest mirror in the chroot complete."

echo "Installing the 'yay' AUR package manager..."

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} curl tar yay-git
else
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} curl tar
    export YAY_VER="11.1.0"
    curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
    tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
    mv yay_${YAY_VER}_x86_64/yay ${WINESAPOS_INSTALL_DIR}/usr/bin/yay
    rm -rf ./yay*
    # Development packages required for building other packages.
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} binutils dkms fakeroot gcc git make
fi

echo "Installing the 'yay' AUR package manager complete."

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} firewalld
    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable firewalld
fi

echo "Configuring user accounts..."
echo -e "root\nroot" | arch-chroot ${WINESAPOS_INSTALL_DIR} passwd root
arch-chroot ${WINESAPOS_INSTALL_DIR} useradd --create-home winesap
echo -e "winesap\nwinesap" | arch-chroot ${WINESAPOS_INSTALL_DIR} passwd winesap
echo "winesap ALL=(root) NOPASSWD:ALL" > ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
chmod 0440 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
echo "Configuring user accounts complete."

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo "Installing AppArmor..."

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} apparmor apparmor-profiles
    else
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} apparmor
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} krathalans-apparmor-profiles-git
    fi

    arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable apparmor
    echo "Installing AppArmor complete."
fi

echo "Installing 'crudini' from the AUR..."
# These packages have to be installed in this exact order.
# Dependency for 'python-iniparse'. Refer to: https://aur.archlinux.org/packages/python-iniparse/.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} python-tests
# Dependency for 'crudini'.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} python-iniparse
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} crudini
echo "Installing 'crudini' from the AUR complete."

echo "Enabling additional repositories..."
# 32-bit multilib libraries.
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf multilib Include /etc/pacman.d/mirrorlist

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf holo Include /etc/pacman.d/mirrorlist
    arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf holo SigLevel Never
    arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf jupiter Include /etc/pacman.d/mirrorlist
    arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf jupiter SigLevel Never
fi

arch-chroot ${WINESAPOS_INSTALL_DIR} pacman -Sy
echo "Enabling additional repositories complete."

echo "Installing additional file system support..."
echo "APFS"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} apfsprogs-git linux-apfs-rw-dkms-git
echo "Btrfs"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} btrfs-progs
echo "ext3 and ext4"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} e2fsprogs lib32-e2fsprogs
echo "exFAT"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} exfatprogs
echo "FAT12, FAT16, and FAT32"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} dosfstools
echo "HFS and HFS+"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} hfsprogs
echo "NTFS"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} ntfs-3g
echo "XFS"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} xfsprogs
echo "ZFS"
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} zfs-dkms zfs-utils
echo -e "apfs\nbtrfs\next4\nexfat\nfat\nhfs\nhfsplus\nntfs3\nzfs" > ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-file-systems.conf
echo "Installing additional file system support complete."

echo "Installing sound drivers..."
# Install the PipeWire sound driver.
## PipeWire.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pipewire lib32-pipewire pipewire-media-session
## PipeWire backwards compatibility.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pipewire-alsa pipewire-jack lib32-pipewire-jack pipewire-pulse pipewire-v4l2 lib32-pipewire-v4l2
## Enable the required services.
## Manually create the 'systemctl --user enable' symlinks as the command does not work in a chroot.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/systemd/user/default.target.wants/
arch-chroot ${WINESAPOS_INSTALL_DIR} ln -s /usr/lib/systemd/user/pipewire.service /home/winesap/.config/systemd/user/default.target.wants/pipewire.service
arch-chroot ${WINESAPOS_INSTALL_DIR} ln -s /usr/lib/systemd/user/pipewire-pulse.service /home/winesap/.config/systemd/user/default.target.wants/pipewire-pulse.service
# Custom systemd service to mute the audio on start.
# https://github.com/LukeShortCloud/winesapOS/issues/172
cp ../files/winesapos-mute.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/user/
cp ./winesapos-mute.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
arch-chroot ${WINESAPOS_INSTALL_DIR} ln -s /etc/systemd/user/winesapos-mute.service /home/winesap/.config/systemd/user/default.target.wants/winesapos-mute.service
# PulseAudio Control is a GUI used for managing PulseAudio (or, in our case, PipeWire-Pulse).
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pavucontrol
echo "Installing sound drivers complete."

echo "Installing additional packages..."
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} clamav clamtk ffmpeg jre8-openjdk keepassxc libdvdcss libreoffice lm_sensors man-db mlocate nano ncdu nmap openssh python python-pip rsync shutter smartmontools sudo terminator tmate transmission-cli transmission-qt wget veracrypt vim vlc zstd
# Download an offline database for ClamAV.
arch-chroot ${WINESAPOS_INSTALL_DIR} freshclam

# Etcher by balena.
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} etcher
elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} etcher-bin
elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} balena-etcher
fi
echo "Installing additional packages complete."

echo "Installing additional packages from the AUR..."
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} firefox-esr-bin qdirstat

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} peazip-gtk2-bin
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} peazip-qt-bin
fi

echo "Installing additional packages from the AUR complete."

echo "Installing Oh My Zsh..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} oh-my-zsh zsh
else
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} zsh
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} oh-my-zsh-git
fi

cp ${WINESAPOS_INSTALL_DIR}/usr/share/oh-my-zsh/zshrc ${WINESAPOS_INSTALL_DIR}/home/winesap/.zshrc
chown 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap/.zshrc
echo "Installing Oh My Zsh complete."

echo "Installing the Linux kernels..."

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux510 linux510-headers linux515 linux515-headers
else
    # The SteamOS repository 'holo' also provides heavily modified versions of these packages that do not work.
    # Those packages use a non-standard location for the kernel and modules.
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} core/linux-lts core/linux-lts-headers

    # We want to install two Linux kernels. 'linux-lts' currently provides 5.15.
    # Then we install 'linux-neptune' (5.13) on SteamOS or 'linux-lts510' on Arch Linux.
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux-neptune linux-neptune-headers
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        # This repository contains binary/pre-built packages for Arch Linux LTS kernels.
        arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-key 76C6E477042BFE985CC220BD9C08A255442FAFF0
        arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-key --lsign 76C6E477042BFE985CC220BD9C08A255442FAFF0
        arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf kernel-lts Server 'https://repo.m2x.dev/current/$repo/$arch'
        arch-chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y --noconfirm
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux-lts510 linux-lts510-headers
    fi

fi

if [[ "${WINESAPOS_DISABLE_KERNEL_UPDATES}" == "true" ]]; then
    echo "Setting up Pacman to disable Linux kernel updates..."

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux515 linux515-headers linux510 linux510-headers"
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-lts510 linux-lts510-headers"
    # On SteamOS, also avoid the 'jupiter/linux-firmware-neptune' package as it will replace 'core/linux-firmware' and only has drivers for the Steam Deck.
    # Also void 'holo/grub' becauase SteamOS has a heavily modified version of GRUB for their A/B partitions compared to the vanilla 'core/grub' package.
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-neptune linux-neptune-headers linux-firmware-neptune grub"
    fi

    echo "Setting up Pacman to disable Linux kernel updates complete."
else

    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        # SteamOS ships heavily modified version of the Linux LTS packages that do not work with upstream GRUB.
        # Even if WINESAPOS_DISABLE_KERNEL_UPDATES=false, we cannot risk breaking a system if users rely on Linux LTS for their system to boot.
        # The real solution is for Pacman to support ignoring specific packages from specific repositories:
        # https://bugs.archlinux.org/task/20361
        arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-firmware-neptune grub"
    fi

fi

arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux-firmware
# Install optional firmware.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} \
  linux-firmware-bnx2x \
  linux-firmware-liquidio \
  linux-firmware-marvell \
  linux-firmware-mellanox \
  linux-firmware-nfp \
  linux-firmware-qcom \
  linux-firmware-qlogic \
  linux-firmware-whence

clear_cache
echo "Installing the Linux kernels complete."

echo "Optimizing battery life..."
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} auto-cpufreq
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable auto-cpufreq
echo "Optimizing battery life complete."

echo "Minimizing writes to the disk..."
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/systemd/journald.conf Journal Storage volatile
echo "vm.swappiness=10" >> ${WINESAPOS_INSTALL_DIR}/etc/sysctl.d/00-winesapos.conf
echo "Minimizing writes to the disk compelete."

echo "Setting up the desktop environment..."
# Install Xorg.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} xorg-server lib32-mesa mesa xorg-server xorg-xinit xterm xf86-input-libinput xf86-video-amdgpu xf86-video-intel xf86-video-nouveau
# Install Light Display Manager.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lightdm lightdm-gtk-greeter
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lightdm-settings
else
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} lightdm-settings
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    echo "Installing the Cinnamon desktop environment..."
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cinnamon

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cinnamon-sounds cinnamon-wallpapers manjaro-cinnamon-settings manjaro-settings-manager
        # Install Manjaro specific Cinnamon theme packages.
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} adapta-maia-theme kvantum-manjaro
        # Image gallery.
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pix
    else
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} pix
    fi

    echo "Installing the Cinnamon desktop environment complete."
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    echo "Installing the KDE Plasma desktop environment..."
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} plasma-meta plasma-nm
    # Dolphin file manager and related plugins.
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} dolphin ffmpegthumbs kdegraphics-thumbnailers konsole
    # Image gallery.
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gwenview phonon-qt5-vlc

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} manjaro-kde-settings manjaro-settings-manager-kcm manjaro-settings-manager-knotifier
        # Install Manjaro specific KDE Plasma theme packages.
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} breath-classic-icon-themes breath-wallpapers plasma5-themes-breath sddm-breath-theme
    elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        # This hook is required to prevent Steam from launching during login.
        # https://github.com/LukeShortCloud/winesapOS/issues/242
        cp ../files/steamdeck-kde-presets.hook ${WINESAPOS_INSTALL_DIR}/usr/share/libalpm/hooks/
        # Vapor theme from Valve.
        arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} steamdeck-kde-presets
    fi

    echo "Installing the KDE Plasma desktop environment complete."
fi

# Start LightDM. This will provide an option of which desktop environment to load.
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable lightdm
# Install Bluetooth.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} bluez bluez-utils blueman bluez-qt
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable bluetooth
# Install webcam software.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cheese
## This is required to turn Bluetooth on or off.
arch-chroot ${WINESAPOS_INSTALL_DIR} usermod -a -G rfkill winesap
# Install printer drivers.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cups libcups lib32-libcups bluez-cups cups-pdf usbutils
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable cups
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
echo 'Thank you for choosing winesapOS! Please open any bug or feature requests on our GitHub page.

https://github.com/LukeShortCloud/winesapOS/issues

Upon first login, the "winesapOS First-Time Setup" wizard will launch. It will help setup graphics drivers, the locale, and time zone. The desktop shortcut is located on the desktop and can be manually ran again at any time.

Use the "winesapOS Upgrade" wizard to upgrade winesapOS features and/or system system packages. Otherwise, use "Add/Remove Software" (Pamac) to upgrade system packages.

Here is a list of all of the applications found on the desktop and their use-case:

- Add/Remove Software = Pamac. A package manager for official Arch Linux, Arch Linux User Repository (AUR), Flatpak, and Snap packages.
- BalenaEtcher = An image flashing utility.
- Bluetooth Manager = A bluetooth pairing utility (Blueman).
- Bottles = A utility for installing any Windows program.
- Cheese = A webcam utility.
- Clamtk = An anti-virus scanner.
- Discord Canary = A Discord chat client.
- Dolphin = On builds with the KDE Plasma desktop environment only. A file manager.
- Firefox ESR = A stable web browser.
- Firewall = On the secure image only. A GUI for managing firewalld.
- Google Chrome = A newer web browser.
- Gwenview = On builds with the KDE Plasma desktop environment only. An image gallery application.
- Heroic Games Launcher - A game launcher for Epic Games Store games.
- KeePassXC = A cross-platform password manager.
- LibreOffice = An office suite.
- Ludusavi = A game save files manager.
- Lutris - GameMode = A game launcher for any game.
- MultiMC - GameMode = A Minecraft and mods game launcher.
- Nemo = On builds with the Cinnamon desktop environment only. A file manager.
- OBS Studio = A recording and streaming utility.
- PeaZip = An archive/compression utility.
- Pix = On builds with the Cinnamon desktop environment only. An image gallery application.
- ProtonUp-Qt = A manager Steam Play compatibility tools.
- QDirStat = A storage usage utility.
- Shutter = A screenshot utility.
- Steam Desktop - GameMode = The original Steam desktop client.
- Steam Deck - GameMode = The Steam Deck client.
- Terminator = A terminal emulator.
- Transmission = A torrent utility.
- VeraCrypt = A cross-platform encryption utility.
- VLC media player = A media player that can play almost any format.
- winesapOS First-Time Setup = A utility for setting up the correct graphics drivers, locale, and time zone.
- ZeroTier GUI = A VPN utility.' > ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/README.txt
echo "Setting up the desktop environment complete."

echo 'Setting up the "pamac" package manager...'
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pamac-gtk pamac-cli libpamac-flatpak-plugin libpamac-snap-plugin
else
    # This package needs to be manually removed first as 'pamac-all' will
    # install a conflicting package called 'archlinux-appstream-data-pamac'.
    # The KDE Plasma package 'discover' depends on 'archlinux-appstream-data'.
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman --noconfirm -Rd --nodeps archlinux-appstream-data
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} pamac-all
fi
echo "Setting up GUI package managers..."
# Enable all Pamac plugins.
sed -i s'/^\#EnableAUR/EnableAUR/'g ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf
sed -i s'/^\#CheckAURUpdates/CheckAURUpdates/'g ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf
## These 3 configuration options do not exist on a default installation of Pamac.
## They are added automatically after it is first launched. Instead, we add them now.
echo EnableFlatpak >> ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf
echo CheckFlatpakUpdates >> ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf
## There is no "CheckSnapUpdates" configuration setting.
echo EnableSnap >> ${WINESAPOS_INSTALL_DIR}/etc/pamac.conf

clear_cache
echo "Setting up GUI package managers complete."

echo "Installing gaming tools..."
# Vulkan drivers.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} vulkan-intel lib32-vulkan-intel vulkan-radeon lib32-vulkan-radeon
# GameMode.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gamemode lib32-gamemode
# Gamescope.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gamescope
# MangoHUD.
if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    # MangoHUD is in the 'jupiter' repository.
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} mangohud lib32-mangohud
else
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} mangohud lib32-mangohud
fi
# GOverlay.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} goverlay
# MultiMC for Minecraft.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} multimc-bin
# Ludusavi.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} ludusavi
# Lutris.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lutris
# Heoric Games Launcher (for Epic Games Store games).
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} heroic-games-launcher-bin
# Steam.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb
if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} steam-manjaro steam-native
else
    arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} steam steam-native-runtime
fi
# Enable the Steam Deck client beta.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/package/
echo "steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d" > ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/package/beta
# Wine GloriousEggroll (GE).
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} wine-ge-custom
# Full installation of optional Wine dependencies.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} winetricks alsa-lib alsa-plugins cups dosbox giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 vkd3d vulkan-icd-loader wine_gecko wine-mono
# protontricks. 'wine-staging' is installed first because otherwise 'protontricks' depends on 'winetricks' which depends on 'wine' by default.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} protontricks
# ProtonUp-Qt.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} protonup-qt
# Proton GE for Steam.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/
PROTON_GE_VERSION="GE-Proton7-8"
curl https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_GE_VERSION}/${PROTON_GE_VERSION}.tar.gz --location --output ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
tar -x -v -f ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz --directory ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/
rm -f ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
chown -R 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap
# Bottles for running any Windows game or application.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} bottles
# Discord.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} discord-canary
# Open Broadcaster Software (OBS) Studio.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} obs-studio
# ZeroTier VPN.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} zerotier-one
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} zerotier-gui-git
## ZeroTier GUI will fail to launch with a false-positive error if the service is not running.
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable zerotier-one
echo "Installing gaming tools complete."

echo "Setting up desktop shortcuts..."
mkdir ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/multimc.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
sed -i s'/Exec=multimc/Exec=\/usr\/bin\/gamemoderun\ multimc/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/multimc.desktop
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/multimc.desktop "Desktop Entry" Name "MultiMC - GameMode"
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/heroic.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop
sed -i s'/Exec=\/opt\/Heroic\/heroic\ \%U/Exec=\/usr\/bin\/gamemoderun \/opt\/Heroic\/heroic\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/heroic_games_launcher.desktop "Desktop Entry" Name "Heroic Games Launcher - GameMode"
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/net.lutris.Lutris.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop
sed -i s'/Exec=lutris\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/lutris\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/lutris.desktop "Desktop Entry" Name "Lutris - GameMode"
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/steam.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_runtime.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam-runtime\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_runtime.desktop
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/steam_runtime.desktop "Desktop Entry" Name "Steam Desktop - GameMode"
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/steam.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_deck_runtime.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam-runtime\ -gamepadui\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/steam_deck_runtime.desktop
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/steam_deck_runtime.desktop "Desktop Entry" Name "Steam Deck - GameMode"
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/appimagelauncher.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/blueman-manager.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/com.usebottles.bottles.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.gnome.Cheese.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/clamtk.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/opt/discord-canary/discord-canary.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/balena-etcher-electron.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/firefox-esr.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/lib/libreoffice/share/xdg/startcenter.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/libreoffice-startcenter.desktop
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/io.github.benjamimgois.goverlay.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.keepassxc.KeePassXC.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/ludusavi.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/com.obsproject.Studio.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.manjaro.pamac.manager.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/peazip.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/net.davidotek.pupgui2.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/qdirstat.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/shutter.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/terminator.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/transmission-qt.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/veracrypt.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/vlc.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/zerotier-gui.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/nemo.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/pix.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.kde.dolphin.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.kde.gwenview.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
fi

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/firewall-config.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
fi

# Fix permissions on the desktop shortcuts.
chmod +x ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/*.desktop
chown -R 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop
echo "Setting up desktop shortcuts complete."

echo "Setting up Mac drivers..."
# Sound driver for Linux <= 5.12.
arch-chroot ${WINESAPOS_INSTALL_DIR} git clone https://github.com/LukeShortCloud/snd_hda_macbookpro.git -b mac-linux-gaming-stick
arch-chroot ${WINESAPOS_INSTALL_DIR} /bin/zsh snd_hda_macbookpro/install.cirrus.driver.sh
echo "snd-hda-codec-cirrus" >> ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-sound.conf
# Sound driver for Linux 5.15.
# https://github.com/LukeShortCloud/winesapOS/issues/152
arch-chroot ${WINESAPOS_INSTALL_DIR} sh -c 'git clone https://github.com/egorenar/snd-hda-codec-cs8409.git;
  cd snd-hda-codec-cs8409;
  export KVER=$(ls -1 /lib/modules/ | grep -P "^5.15");
  make;
  make install'
echo "snd-hda-codec-cs8409" >> ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-sound.conf
# MacBook Pro Touch Bar driver.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} macbook12-spi-driver-dkms
sed -i s'/MODULES=(/MODULES=(applespi spi_pxa2xx_platform intel_lpss_pci apple_ibridge apple_ib_tb apple_ib_als /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
# iOS device management via 'usbmuxd' and a workaround required for the Touch Bar to continue to work.
# 'uxbmuxd' and MacBook Pro Touch Bar bug reports:
# https://github.com/libimobiledevice/usbmuxd/issues/138
# https://github.com/roadrunner2/macbook12-spi-driver/issues/42
cp ../files/winesapos-touch-bar-usbmuxd-fix.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
cp ./winesapos-touch-bar-usbmuxd-fix.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable winesapos-touch-bar-usbmuxd-fix
# MacBook Pro >= 2018 require a special T2 Linux driver for the keyboard and mouse to work.
arch-chroot ${WINESAPOS_INSTALL_DIR} git clone https://github.com/LukeShortCloud/mbp2018-bridge-drv --branch mac-linux-gaming-stick /usr/src/apple-bce-0.1

for kernel in $(ls -1 ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/ | grep -P "^[0-9]+"); do
    # This will sometimes fail the first time it tries to install.
    arch-chroot ${WINESAPOS_INSTALL_DIR} timeout 120s dkms install -m apple-bce -v 0.1 -k ${kernel}

    if [ $? -ne 0 ]; then
        arch-chroot ${WINESAPOS_INSTALL_DIR} dkms install -m apple-bce -v 0.1 -k ${kernel}
    fi

done

sed -i s'/MODULES=(/MODULES=(apple-bce /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
# Blacklist Mac WiFi drivers are these are known to be unreliable.
echo -e "\nblacklist brcmfmac\nblacklist brcmutil" >> ${WINESAPOS_INSTALL_DIR}/etc/modprobe.d/winesapos.conf
echo "Setting up Mac drivers complete."

echo "Setting mkinitcpio modules and hooks order..."

# Required fix for:
# https://github.com/LukeShortCloud/winesapOS/issues/94
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    # Also add 'keymap' and 'encrypt' for LUKS encryption support.
    sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)/'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
else
    sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)/'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
fi

echo "Setting mkinitcpio modules and hooks order complete."

echo "Setting up the bootloader..."
arch-chroot ${WINESAPOS_INSTALL_DIR} mkinitcpio -p linux510 -p linux515
# These two configuration lines allow the GRUB menu to show on boot.
# https://github.com/LukeShortCloud/winesapOS/issues/41
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_TIMEOUT 10
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_TIMEOUT_STYLE menu

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo "Enabling AppArmor in the Linux kernel..."
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    echo "Enabling AppArmor in the Linux kernel complete."
fi

if [[ "${WINESAPOS_CPU_MITIGATIONS}" == "false" ]]; then
    echo "Enabling Linux kernel-level CPU exploit mitigations..."
    sed -i s'/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mitigations=off /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    echo "Enabling Linux kernel-level CPU exploit mitigations done."
fi

# Enable Btrfs with zstd compression support.
# This will help allow GRUB to save the selected kernel for the next boot.
sed -i s'/GRUB_PRELOAD_MODULES="/GRUB_PRELOAD_MODULES="btrfs zstd /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub
# Disable the submenu to show all boot kernels/options on the main GRUB menu.
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_DISABLE_SUBMENU y
# These two lines allow saving the selected kernel for next boot.
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_DEFAULT saved
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_SAVEDEFAULT true
# Setup the Steam Big Picture theme in GRUB.
# This theme needs to exist in the '/boot/' mount because if the root file system is encrypted, then the theme cannot be found.
git clone --depth=1 https://github.com/LegendaryBibo/Steam-Big-Picture-Grub-Theme ${WINESAPOS_INSTALL_DIR}/boot/grub/themes/SteamBP
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_THEME /boot/grub/themes/SteamBP/theme.txt
arch-chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_GFXMODE 1600x1200,1024x768,800x600,640x480,auto
# Remove the whitespace from the 'GRUB_* = ' lines that 'crudini' creates.
sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" ${WINESAPOS_INSTALL_DIR}/etc/default/grub

arch-chroot ${WINESAPOS_INSTALL_DIR} grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS --removable
parted ${DEVICE} set 1 bios_grub on
arch-chroot ${WINESAPOS_INSTALL_DIR} grub-install --target=i386-pc ${DEVICE}

if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="cryptdevice=LABEL=winesapos-luks:cryptroot root='$(echo ${root_partition} | sed -e s'/\//\\\//'g)' /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub
fi

# Configure higher polling frequencies for better compatibility with input devices.
sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="usbhid.jspoll=1 usbhid.kbpoll=1 usbhid.mousepoll=1 /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub

# Configure the "none" I/O scheduler for better performance on flash and SSD devices.
sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="elevator=none /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub

# Configure Arch Linux to load the Linux kernels in the correct order of newest to oldest.
# This will make the newest kernel be bootable. For example, 'linux' will be the default over 'linux-lts'.
# Before:
#   linux=`version_find_latest $list`
# After:
#   linux=`echo $list | tr ' ' '\n' | sort -V | head -1 | cat`
# https://github.com/LukeShortCloud/winesapOS/issues/144
if [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    sed -i s"/linux=.*/linux=\`echo \$list | tr ' ' '\\\n' | sort -V | head -1 | cat\`/"g ${WINESAPOS_INSTALL_DIR}/etc/grub.d/10_linux
fi

arch-chroot ${WINESAPOS_INSTALL_DIR} grub-mkconfig -o /boot/grub/grub.cfg
echo "Setting up the bootloader complete."

echo "Setting up root file system resize script..."
# This package provides the required 'growpart' command.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} cloud-guest-utils
# Copy from the current directory which should be "scripts".
cp ./winesapos-resize-root-file-system.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
cp ../files/winesapos-resize-root-file-system.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable winesapos-resize-root-file-system
echo "Setting up root file system resize script complete."

echo "Setting up the first-time setup script..."
# winesapOS first-time setup script.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/ ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/autostart/
cp ./winesapos-setup.sh ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
cp ../files/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
ln -s /home/winesap/.winesapos/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/autostart/winesapos-setup.desktop
ln -s /home/winesap/.winesapos/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/winesapos-setup.desktop
## Install th required dependency for the setup script.
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} kdialog
# winesapOS remote upgrade script.
cp ./winesapos-upgrade-remote-stable.sh ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
cp ../files/winesapos-upgrade.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
ln -s /home/winesap/.winesapos/winesapos-upgrade.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/winesapos-upgrade.desktop
# winesapOS icon used for both desktop shortcuts.
cp ../files/winesapos_logo_icon.png ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/winesapos_logo_icon.png
echo "Setting up the first-time setup script complete."

echo "Configuring Btrfs backup tools..."
arch-chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} grub-btrfs snapper snap-pac
cp ../files/etc-snapper-configs-root ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/root
cp ../files/etc-snapper-configs-root ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/home
sed -i s'/SUBVOLUME=.*/SUBVOLUME=\"\/home\"/'g ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/home
arch-chroot ${WINESAPOS_INSTALL_DIR} chown -R root.root /etc/snapper/configs
btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/.snapshots
btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/home/.snapshots
# Ensure the new "root" and "home" configurations will be loaded.
sed -i s'/SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"root home\"/'g ${WINESAPOS_INSTALL_DIR}/etc/conf.d/snapper
arch-chroot ${WINESAPOS_INSTALL_DIR} systemctl enable snapper-timeline.timer snapper-cleanup.timer
echo "Configuring Btrfs backup tools complete."

echo "Resetting the machine-id file..."
echo -n | tee ${WINESAPOS_INSTALL_DIR}/etc/machine-id
rm -f ${WINESAPOS_INSTALL_DIR}/var/lib/dbus/machine-id
arch-chroot ${WINESAPOS_INSTALL_DIR} ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Resetting the machine-id file complete."

echo "Setting up winesapOS files..."
mkdir ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
cp ../VERSION ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
cp /tmp/winesapos-install.log ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
# Continue to log to the file after it has been copied over.
exec > >(tee -a ${WINESAPOS_INSTALL_DIR}/etc/winesapos/winesapos-install.log) 2>&1
echo "Setting up winesapOS files complete."

echo "Cleaning up..."

if [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "false" ]]; then
    echo "Require the 'winesap' user to enter a password when using sudo..."
    # Temporarily add write permissions back to the file so we can modify it.
    chmod 0644 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    echo "winesap ALL=(root) ALL" > ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    # This command is required for the user 'winesapos-mute.service'.
    echo "winesap ALL=(root) NOPASSWD: /usr/bin/dmidecode" >> ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    chmod 0440 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    echo "Require the 'winesap' user to enter a password when using sudo complete."
fi

chown -R 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap
clear_cache
echo "Cleaning up complete."

echo "Configuring swap file..."
touch ${WINESAPOS_INSTALL_DIR}/swap/swapfile
# Avoid Btrfs copy-on-write.
chattr +C ${WINESAPOS_INSTALL_DIR}/swap/swapfile
# Now fill in the 2 GiB swap file.
dd if=/dev/zero of=${WINESAPOS_INSTALL_DIR}/swap/swapfile bs=1M count=2000
# A swap file requires strict permissions to work.
chmod 0600 ${WINESAPOS_INSTALL_DIR}/swap/swapfile
mkswap ${WINESAPOS_INSTALL_DIR}/swap/swapfile
swaplabel --label winesapos-swap ${WINESAPOS_INSTALL_DIR}/swap/swapfile
echo "Configuring swap file complete."

if [[ "${WINESAPOS_PASSWD_EXPIRE}" == "true" ]]; then

    for u in root winesap; do
        echo -n "Setting the password for ${u} to expire..."
        arch-chroot ${WINESAPOS_INSTALL_DIR} passwd --expire ${u}
        echo "Done."
    done

fi

echo "Populating trusted Pacman keyrings..."
arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-key --refresh-keys

if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-key --populate archlinux manjaro
else
    # SteamOS does not provide GPG keys so only update the Arch Linux keyring.
    arch-chroot ${WINESAPOS_INSTALL_DIR} pacman-key --populate archlinux
fi

echo "Populating trusted Pacman keyrings done."

echo "Syncing files to disk..."
sync
echo "Syncing files to disk complete."

echo "Running tests..."
zsh ./winesapos-tests.sh
echo "Running tests complete."

echo "Done."
echo "End time: $(date)"
