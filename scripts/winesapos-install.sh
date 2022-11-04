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

WINESAPOS_IMAGE_TYPE="${WINESAPOS_IMAGE_TYPE:-performance}"
WINESAPOS_INSTALL_DIR="${WINESAPOS_INSTALL_DIR:-/winesapos}"
WINESAPOS_DISTRO="${WINESAPOS_DISTRO:-steamos}"
WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
WINESAPOS_ENABLE_TESTING_REPO="${WINESAPOS_ENABLE_TESTING_REPO:-false}"
WINESAPOS_DE="${WINESAPOS_DE:-plasma}"
WINESAPOS_ENCRYPT="${WINESAPOS_ENCRYPT:-false}"
WINESAPOS_ENCRYPT_PASSWORD="${WINESAPOS_ENCRYPT_PASSWORD:-password}"
WINESAPOS_LOCALE="${WINESAPOS_LOCALE:-en_US.UTF-8 UTF-8}"
WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
WINESAPOS_DISABLE_KERNEL_UPDATES="${WINESAPOS_DISABLE_KERNEL_UPDATES:-true}"
WINESAPOS_APPARMOR="${WINESAPOS_APPARMOR:-false}"
WINESAPOS_SUDO_NO_PASSWORD="${WINESAPOS_SUDO_NO_PASSWORD:-true}"
WINESAPOS_DISABLE_KWALLET="${WINESAPOS_DISABLE_KWALLET:-true}"
WINESAPOS_ENABLE_KLIPPER="${WINESAPOS_ENABLE_KLIPPER:-true}"
WINESAPOS_INSTALL_GAMING_TOOLS="${WINESAPOS_INSTALL_GAMING_TOOLS:-true}"
WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS="${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS:-true}"
WINESAPOS_AUTO_LOGIN="${WINESAPOS_AUTO_LOGIN:-true}"
WINESAPOS_DEVICE="${WINESAPOS_DEVICE:-vda}"
WINESAPOS_ENABLE_PORTABLE_STORAGE="${WINESAPOS_ENABLE_PORTABLE_STORAGE:-true}"
WINESAPOS_BUILD_IN_VM_ONLY="${WINESAPOS_BUILD_IN_VM_ONLY:-true}"
WINESAPOS_BUILD_CHROOT_ONLY="${WINESAPOS_BUILD_CHROOT_ONLY:-false}"
DEVICE="/dev/${WINESAPOS_DEVICE}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u winesap yay --noconfirm -S --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

if [[ "${WINESAPOS_BUILD_IN_VM_ONLY}" == "true" ]]; then
    lscpu | grep "Hypervisor vendor:"
    if [ $? -ne 0 ]
    then
        echo "This build is not running in a virtual machine. Exiting to be safe."
        exit 1
    fi
fi

clear_cache() {
    chroot ${WINESAPOS_INSTALL_DIR} pacman --noconfirm -S -c -c
    # Each directory gets deleted separately in case the directory does not exist yet.
    # Otherwise, the entire 'rm' command will not run if one of the directories is not found.
    rm -rf ${WINESAPOS_INSTALL_DIR}/var/cache/pacman/pkg/*
    rm -rf ${WINESAPOS_INSTALL_DIR}/home/winesap/.cache/go-build/*
    rm -rf ${WINESAPOS_INSTALL_DIR}/home/winesap/.cache/paru/*
    rm -rf ${WINESAPOS_INSTALL_DIR}/home/winesap/.cache/yay/*
    rm -rf ${WINESAPOS_INSTALL_DIR}/home/winesap/.cargo/*
    rm -rf ${WINESAPOS_INSTALL_DIR}/tmp/*
}

if [ -n "${WINESAPOS_HTTP_PROXY_CA}" ]; then
    echo "Configuring the proxy certificate authority in the live environment..."
    cp "${WINESAPOS_HTTP_PROXY_CA}" /etc/ca-certificates/trust-source/anchors/
    update-ca-trust
    echo "Configuring the proxy certificate authority in the live environment complete."
fi

if [ -n "${WINESAPOS_HTTP_PROXY}" ]; then
    echo "Configuring the proxy in the live environment..."
    export http_proxy="${WINESAPOS_HTTP_PROXY}"
    export https_proxy="${http_proxy}"
    export ftp_proxy="${http_proxy}"
    export rsync_proxy="${http_proxy}"
    export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
    export HTTP_PROXY="${http_proxy}"
    export HTTPS_PROXY="${http_proxy}"
    export FTP_PROXY="${http_proxy}"
    export RSYNC_PROXY="${http_proxy}"
    export NO_PROXY="${no_proxy}"
    echo "Configuring the proxy in the live environment complete."
fi

if [[ "${WINESAPOS_CREATE_DEVICE}" == "true" ]]; then

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        fallocate -l 28G winesapos.img
    else
        fallocate -l 12G winesapos.img
    fi

    # The output should be "/dev/loop0" by default.
    DEVICE="$(losetup --partscan --find --show winesapos.img)"
fi

mkdir -p ${WINESAPOS_INSTALL_DIR}

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    DEVICE_WITH_PARTITION="${DEVICE}"
    echo ${DEVICE} | grep -q -P "^/dev/(nvme|loop)"
    if [ $? -eq 0 ]; then
        # "nvme" and "loop" devices separate the device name and partition number by using a "p".
        # Example output: /dev/loop0p
        DEVICE_WITH_PARTITION="${DEVICE}p"
    fi

    echo "Creating partitions..."
    # GPT is required for UEFI boot.
    parted ${DEVICE} mklabel gpt
    # An empty partition is required for BIOS boot backwards compatibility.
    parted ${DEVICE} mkpart primary 2048s 2M

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
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
    else
        # EFI partition.
        parted ${DEVICE} mkpart primary fat32 2M 512M
        parted ${DEVICE} set 2 boot on
        parted ${DEVICE} set 2 esp on
        # Boot partition.
        parted ${DEVICE} mkpart primary ext4 512M 1.5G
        # Root partition uses the rest of the space.
        parted ${DEVICE} mkpart primary btrfs 1.5G 100%
    fi

    # Avoid a race-condition where formatting devices may happen before the system detects the new partitions.
    sync
    partprobe

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        # Formatting via 'parted' does not work so we need to reformat those partitions again.
        mkfs -t exfat ${DEVICE_WITH_PARTITION}2
        # exFAT file systems require labels that are 11 characters or shorter.
        exfatlabel ${DEVICE_WITH_PARTITION}2 wos-drive
        mkfs -t vfat ${DEVICE_WITH_PARTITION}3
        # FAT32 file systems require upper-case labels that are 11 characters or shorter.
        fatlabel ${DEVICE_WITH_PARTITION}3 WOS-EFI
        mkfs -t ext4 ${DEVICE_WITH_PARTITION}4
        e2label ${DEVICE_WITH_PARTITION}4 winesapos-boot

        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup -q luksFormat ${DEVICE_WITH_PARTITION}5
            cryptsetup config ${DEVICE}5 --label winesapos-luks
            echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup luksOpen ${DEVICE_WITH_PARTITION}5 cryptroot
            root_partition="/dev/mapper/cryptroot"
        else
            root_partition="${DEVICE_WITH_PARTITION}5"
        fi

    else
        # Formatting via 'parted' does not work so we need to reformat those partitions again.
        mkfs -t vfat ${DEVICE_WITH_PARTITION}2
        # FAT32 file systems require upper-case labels that are 11 characters or shorter.
        fatlabel ${DEVICE_WITH_PARTITION}2 WOS-EFI
        mkfs -t ext4 ${DEVICE_WITH_PARTITION}3
        e2label ${DEVICE_WITH_PARTITION}3 winesapos-boot

        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup -q luksFormat ${DEVICE_WITH_PARTITION}4
            cryptsetup config ${DEVICE}4 --label winesapos-luks
            echo "${WINESAPOS_ENCRYPT_PASSWORD}" | cryptsetup luksOpen ${DEVICE_WITH_PARTITION}4 cryptroot
            root_partition="/dev/mapper/cryptroot"
        else
            root_partition="${DEVICE_WITH_PARTITION}4"
        fi
    fi

    mkfs -t btrfs ${root_partition}
    btrfs filesystem label ${root_partition} winesapos-root
    echo "Creating partitions complete."

    echo "Mounting partitions..."
    mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}
    btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/home
    mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}/home
    btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/swap
    mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${WINESAPOS_INSTALL_DIR}/swap
    mkdir ${WINESAPOS_INSTALL_DIR}/boot
    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        mount -t ext4 ${DEVICE_WITH_PARTITION}4 ${WINESAPOS_INSTALL_DIR}/boot
    else
        mount -t ext4 ${DEVICE_WITH_PARTITION}3 ${WINESAPOS_INSTALL_DIR}/boot
    fi

    # On SteamOS 3, the package 'holo/filesystem' creates the directory '/efi' and a symlink from '/boot/efi' to it.
    if [[ "${WINESAPOS_DISTRO}" != "steamos" ]]; then
        mkdir ${WINESAPOS_INSTALL_DIR}/boot/efi
        if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
            mount -t vfat ${DEVICE_WITH_PARTITION}3 ${WINESAPOS_INSTALL_DIR}/boot/efi
        else
            mount -t vfat ${DEVICE_WITH_PARTITION}2 ${WINESAPOS_INSTALL_DIR}/boot/efi
        fi
    fi

    for i in tmp var/log var/tmp; do
        mkdir -p ${WINESAPOS_INSTALL_DIR}/${i}
        mount tmpfs -t tmpfs -o nodev,nosuid ${WINESAPOS_INSTALL_DIR}/${i}
    done

    echo "Mounting partitions complete."
fi

echo "Setting up fastest pacman mirror on live media..."

if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    pacman-mirrors --api --protocol https --country United_States
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]]; then
    pacman -S --needed --noconfirm reflector
    reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
fi

pacman -S -y --noconfirm
echo "Setting up fastest pacman mirror on live media complete."

echo "Setting up Pacman parallel package downloads on live media..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g /etc/pacman.conf
echo "Setting up Pacman parallel package downloads on live media complete."

echo "Configuring Pacman to use 'wget' for more reliable downloads on slow internet connections..."
pacman -S --needed --noconfirm wget
sed -i s'/\[options\]/\[options\]\nXferCommand = \/usr\/bin\/wget --passive-ftp -c -O %o %u/'g /etc/pacman.conf
echo "Configuring Pacman to use 'wget' for more reliable downloads on slow internet connections complete."

echo "Installing Arch Linux installation tools on the live media..."
# Required for the 'arch-chroot', 'genfstab', and 'pacstrap' tools.
# These are not provided by default in Manjaro.
/usr/bin/pacman --noconfirm -S --needed arch-install-scripts
echo "Installing Arch Linux installation tools on the live media complete."


if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    if [[ "${WINESAPOS_DISTRO_DETECTED}" != "steamos" ]]; then
        echo "Enabling SteamOS package repositories on Arch Linux distributions..."
        echo '\n[jupiter]\nServer = https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch\nSigLevel = Never\n\n' >> /etc/pacman.conf
        echo '\n[holo]\nServer = https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch\nSigLevel = Never\n\n' >> /etc/pacman.conf
        pacman -S -y -y
        echo "Enabling SteamOS package repositories on Arch Linux distributions complete."
    fi
fi

echo "Installing ${WINESAPOS_DISTRO}..."

if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    pacstrap -i ${WINESAPOS_INSTALL_DIR} holo/filesystem base base-devel wget --noconfirm

    # After the 'holo/filesystem' package has been installed,
    # we can mount the UEFI file system.
    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        mount -t vfat ${DEVICE_WITH_PARTITION}3 ${WINESAPOS_INSTALL_DIR}/efi
    else
        mount -t vfat ${DEVICE_WITH_PARTITION}2 ${WINESAPOS_INSTALL_DIR}/efi
    fi

    rm -f ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    cp ../files/etc-pacman.conf_steamos ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        sed -i s'/Server = https:\/\/mirror.rackspace.com\/archlinux\/$repo\/os\/$arch/Include = \/etc\/pacman.d\/mirrorlist/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    fi

else
    pacstrap -i ${WINESAPOS_INSTALL_DIR} base base-devel --noconfirm
fi

echo "Adding the winesapOS repository..."
if [[ "${WINESAPOS_ENABLE_TESTING_REPO}" == "false" ]]; then
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        sed -i s'/\[jupiter]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[jupiter]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    else
        sed -i s'/\[core]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[core]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    fi
else
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        sed -i s'/\[jupiter]/[winesapos-testing]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[jupiter]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    else
        sed -i s'/\[core]/[winesapos-testing]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\nSigLevel = Never\n\n[core]/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    fi
fi
echo "Adding the winesapOS repository complete."

if [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
    echo "Adding the 32-bit multilb repository..."
    # 32-bit multilib libraries.
    echo -e '\n\n[multilib]\nInclude=/etc/pacman.d/mirrorlist' >> ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
    echo "Adding the 32-bit multilb repository..."
fi

if [ -n "${WINESAPOS_HTTP_PROXY_CA}" ]; then
    echo "Configuring the proxy certificate authority in the chroot..."
    cp "${WINESAPOS_HTTP_PROXY_CA}" ${WINESAPOS_INSTALL_DIR}/etc/ca-certificates/trust-source/anchors/
    chroot ${WINESAPOS_INSTALL_DIR} update-ca-trust
    echo "Configuring the proxy certificate authority in the chroot complete."
fi

# Before we perform our first 'chroot', we need to mount the necessary Linux device, process, and system file systems.
mount --rbind /dev ${WINESAPOS_INSTALL_DIR}/dev
mount -t proc /proc ${WINESAPOS_INSTALL_DIR}/proc
mount --rbind /sys ${WINESAPOS_INSTALL_DIR}/sys
# A DNS resolver also needs to be configured.
echo "nameserver 1.1.1.1" > ${WINESAPOS_INSTALL_DIR}/etc/resolv.conf

# Update repository cache. The extra '-y' is to accept any new keyrings.
chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y -y

# Avoid installing the 'grub' package from SteamOS repositories as it is missing the '/usr/bin/grub-install' binary.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} efibootmgr core/grub mkinitcpio networkmanager
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable NetworkManager systemd-timesyncd
sed -i s'/MODULES=(/MODULES=(btrfs\ /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
echo "${WINESAPOS_LOCALE}" >> ${WINESAPOS_INSTALL_DIR}/etc/locale.gen
chroot ${WINESAPOS_INSTALL_DIR} locale-gen
# Example output: LANG=en_US.UTF-8
echo "LANG=$(echo ${WINESAPOS_LOCALE} | cut -d' ' -f1)" > ${WINESAPOS_INSTALL_DIR}/etc/locale.conf
# Hostname.
echo winesapos > ${WINESAPOS_INSTALL_DIR}/etc/hostname
## This is not a typo. The IPv4 address should '127.0.1.1' instead of '127.0.0.1' to work with systemd.
echo "127.0.1.1    winesapos" >> ${WINESAPOS_INSTALL_DIR}/etc/hosts
## This package provides the 'hostname' command along with other useful network utilities.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} inetutils
echo "Installing ${WINESAPOS_DISTRO} complete."

echo "Setting up Pacman parallel package downloads in chroot..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g ${WINESAPOS_INSTALL_DIR}/etc/pacman.conf
echo "Setting up Pacman parallel package downloads in chroot complete."

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Saving partition mounts to /etc/fstab..."
    sync
    partprobe
    # Force a rescan of labels on the system.
    # https://github.com/LukeShortCloud/winesapOS/issues/251
    systemctl restart systemd-udev-trigger
    sleep 5s
    # On SteamOS 3, '/home/swapfile' gets picked up by the 'genfstab' command.
    genfstab -L ${WINESAPOS_INSTALL_DIR} | grep -v '/home/swapfile' | grep -v tracefs > ${WINESAPOS_INSTALL_DIR}/etc/fstab
    # Add temporary mounts separately instead of using 'genfstab -P' to avoid extra file systems.
    echo "tmpfs               	/tmp      	tmpfs     	rw,nosuid,nodev,inode64	0 0
tmpfs               	/var/log  	tmpfs     	rw,nosuid,nodev,inode64	0 0
tmpfs               	/var/tmp  	tmpfs     	rw,nosuid,nodev,inode64	0 0" >> ${WINESAPOS_INSTALL_DIR}/etc/fstab
    echo "Saving partition mounts to /etc/fstab complete."
fi

echo "Configuring fastest mirror in the chroot..."

# Not required for SteamOS because there is only one mirror and it already uses a CDN.
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    cp ../files/pacman-mirrors.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
    # Enable on first boot.
    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable pacman-mirrors
    # This is required for 'pacman-mirrors' to determine if an IP address has been assigned yet.
    # Once an IP address is assigned, then the `pacman-mirrors' service will start.
    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable NetworkManager-wait-online.service
    # Temporarily set mirrors to United States to use during the build process.
    chroot ${WINESAPOS_INSTALL_DIR} pacman-mirrors --api --protocol https --country United_States
elif [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} reflector
    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable reflector.service
    chroot ${WINESAPOS_INSTALL_DIR} reflector --protocol https --country US --latest 5 --save /etc/pacman.d/mirrorlist
    chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y --noconfirm
fi

echo "Configuring fastest mirror in the chroot complete."

echo "Installing additional package managers..."

# yay.
if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} curl tar yay-git
    else
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} curl tar
        export YAY_VER="11.1.0"
        curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
        tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
        mv yay_${YAY_VER}_x86_64/yay ${WINESAPOS_INSTALL_DIR}/usr/bin/yay
        rm -rf ./yay*
        # Development packages required for building other packages.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} binutils dkms fakeroot gcc git make
    fi
fi
echo 'MAKEFLAGS="-j $(nproc)"' >> ${WINESAPOS_INSTALL_DIR}/etc/makepkg.conf

# Install 'mesa-steamos' and 'lib32-mesa-steamos' graphics driver before 'flatpak'.
# This avoid the 'flatpak' package from installing the conflicting upstream 'mesa' package.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} \
  mesa-steamos \
  libva-mesa-driver-steamos \
  mesa-vdpau-steamos \
  opencl-mesa-steamos \
  vulkan-intel-steamos \
  vulkan-mesa-layers-steamos \
  vulkan-radeon-steamos \
  vulkan-swrast-steamos \
  lib32-mesa-steamos \
  lib32-libva-mesa-driver-steamos \
  lib32-mesa-vdpau-steamos \
  lib32-opencl-mesa-steamos \
  lib32-vulkan-intel-steamos \
  lib32-vulkan-mesa-layers-steamos \
  lib32-vulkan-radeon-steamos \
  lib32-vulkan-swrast-steamos

# Flatpak.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} flatpak
echo "Installing additional package managers complete."

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} firewalld
    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable firewalld
fi

echo "Configuring user accounts..."
echo -e "root\nroot" | chroot ${WINESAPOS_INSTALL_DIR} passwd root
chroot ${WINESAPOS_INSTALL_DIR} useradd --create-home winesap
echo -e "winesap\nwinesap" | chroot ${WINESAPOS_INSTALL_DIR} passwd winesap
echo "winesap ALL=(root) NOPASSWD:ALL" > ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
chmod 0440 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
mkdir ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop
echo "Configuring user accounts complete."

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    echo "Installing AppArmor..."

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} apparmor apparmor-profiles
    else
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} apparmor
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} krathalans-apparmor-profiles-git
    fi

    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable apparmor
    echo "Installing AppArmor complete."
fi

echo "Installing 'crudini' from the AUR..."
# These packages have to be installed in this exact order.
# Dependency for 'python-iniparse'. Refer to: https://aur.archlinux.org/packages/python-iniparse/.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} python-tests
# Dependency for 'crudini'.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} python-iniparse
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} crudini
echo "Installing 'crudini' from the AUR complete."

echo "Installing sound drivers..."
# Install the PipeWire sound driver.
## PipeWire.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pipewire lib32-pipewire wireplumber
## PipeWire backwards compatibility.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pipewire-alsa pipewire-jack lib32-pipewire-jack pipewire-pulse pipewire-v4l2 lib32-pipewire-v4l2
## Enable the required services.
## Manually create the 'systemctl --user enable' symlinks as the command does not work in a chroot.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/systemd/user/default.target.wants/
chroot ${WINESAPOS_INSTALL_DIR} ln -s /usr/lib/systemd/user/pipewire.service /home/winesap/.config/systemd/user/default.target.wants/pipewire.service
chroot ${WINESAPOS_INSTALL_DIR} ln -s /usr/lib/systemd/user/pipewire-pulse.service /home/winesap/.config/systemd/user/default.target.wants/pipewire-pulse.service
# Custom systemd service to mute the audio on start.
# https://github.com/LukeShortCloud/winesapOS/issues/172
cp ../files/winesapos-mute.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/user/
cp ./winesapos-mute.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
chroot ${WINESAPOS_INSTALL_DIR} ln -s /etc/systemd/user/winesapos-mute.service /home/winesap/.config/systemd/user/default.target.wants/winesapos-mute.service
# PulseAudio Control is a GUI used for managing PulseAudio (or, in our case, PipeWire-Pulse).
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} pavucontrol
echo "Installing sound drivers complete."

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    echo "Installing additional packages..."
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} ffmpeg gparted jre8-openjdk libdvdcss lm_sensors man-db mlocate nano ncdu nmap openssh python python-pip rsync shutter smartmontools sudo terminator tmate wget veracrypt vim vlc zstd
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} org.gnome.Cheese com.gitlab.davem.ClamTk com.github.tchx84.Flatseal org.keepassxc.KeePassXC org.libreoffice.LibreOffice io.github.peazip.PeaZip com.transmissionbt.Transmission org.videolan.VLC
    # Download and install offline databases for ClamTk/ClamAV.
    ${CMD_PACMAN_INSTALL} python-pip python-setuptools sudo
    sudo -u root python3 -m pip install --user cvdupdate
    ## The Arch Linux ISO in particular has a very small amount of writeable storage space.
    ## Generate the database in the system temporary directory so that it will go into available RAM space instead.
    mkdir /tmp/cvdupdate/
    rm -rf /root/.cvdupdate
    ln -s /tmp/cvdupdate /root/.cvdupdate
    sudo -u root /root/.local/bin/cvd update
    mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.var/app/com.gitlab.davem.ClamTk/data/.clamtk/db/
    for i in bytecode.cvd daily.cvd main.cvd
        ## This location is used by the ClamTk Flatpak.
        do cp /tmp/cvdupdate/database/${i} ${WINESAPOS_INSTALL_DIR}/home/winesap/.var/app/com.gitlab.davem.ClamTk/data/.clamtk/db/
    done

    # Etcher by balena.
    export ETCHER_VER="1.7.9"
    wget "https://github.com/balena-io/etcher/releases/download/v${ETCHER_VER}/balenaEtcher-${ETCHER_VER}-x64.AppImage" -O ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/balenaEtcher.AppImage
    chmod +x ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/balenaEtcher.AppImage
    echo "Installing additional packages complete."

    echo "Installing additional packages from the AUR..."
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} qdirstat
    echo "Installing additional packages from the AUR complete."

else
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lm_sensors man-db nano openssh rsync sudo terminator tmate wget vim zstd
fi

echo "Installing Firefox ESR..."
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} firefox-esr-bin
echo "Installing Firefox ESR complete."

echo "Installing Oh My Zsh..."

if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} oh-my-zsh zsh
else
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} zsh
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} oh-my-zsh-git
fi

cp ${WINESAPOS_INSTALL_DIR}/usr/share/oh-my-zsh/zshrc ${WINESAPOS_INSTALL_DIR}/home/winesap/.zshrc
chown 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap/.zshrc
echo "Installing Oh My Zsh complete."

clear_cache
if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Installing the Linux kernels..."

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux510 linux510-headers linux515 linux515-headers
    else
        # The SteamOS repository 'holo' also provides heavily modified versions of these packages that do not work.
        # Those packages use a non-standard location for the kernel and modules.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} core/linux-lts core/linux-lts-headers

        # We want to install two Linux kernels. 'linux-lts' currently provides 5.15.
        # Then we install 'linux-steamos' (5.13) on SteamOS or 'linux-lts510' on Arch Linux.
        if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
            chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} linux-steamos linux-steamos-headers
        elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
            # This repository contains binary/pre-built packages for Arch Linux LTS kernels.
            chroot ${WINESAPOS_INSTALL_DIR} pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-key 76C6E477042BFE985CC220BD9C08A255442FAFF0
            chroot ${WINESAPOS_INSTALL_DIR} pacman-key --lsign 76C6E477042BFE985CC220BD9C08A255442FAFF0
            chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf kernel-lts Server 'https://repo.m2x.dev/current/$repo/$arch'
            chroot ${WINESAPOS_INSTALL_DIR} pacman -S -y --noconfirm
            chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux-lts510 linux-lts510-headers
        fi

    fi

    if [[ "${WINESAPOS_DISABLE_KERNEL_UPDATES}" == "true" ]]; then
        echo "Setting up Pacman to disable Linux kernel updates..."

        if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
            chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux515 linux515-headers linux510 linux510-headers"
        elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
            chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-lts510 linux-lts510-headers"
        # On SteamOS, also avoid the 'jupiter/linux-firmware-neptune' package as it will replace 'core/linux-firmware' and only has drivers for the Steam Deck.
        elif [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
            if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
                # Also void 'holo/grub' becauase SteamOS has a heavily modified version of GRUB for their A/B partitions compared to the vanilla 'core/grub' package.
                chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-steamos linux-steamos-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug grub"
            else
                chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-steamos linux-steamos-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug"
            fi
        fi

        echo "Setting up Pacman to disable Linux kernel updates complete."
    else

        if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
            # SteamOS ships heavily modified version of the Linux LTS packages that do not work with upstream GRUB.
            # Even if WINESAPOS_DISABLE_KERNEL_UPDATES=false, we cannot risk breaking a system if users rely on Linux LTS for their system to boot.
            # The real solution is for Pacman to support ignoring specific packages from specific repositories:
            # https://bugs.archlinux.org/task/20361
            if [[ "${WINESAPOS_DISTRO_DETECTED}" == "steamos" ]]; then
                chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/pacman.conf options IgnorePkg "linux-lts linux-lts-headers linux-firmware-neptune linux-firmware-neptune-rtw-debug grub"
            fi
        fi

    fi

    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} linux-firmware
    echo "Installing the Linux kernels complete."
fi
clear_cache

echo "Installing additional file system support..."
echo "APFS"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} apfsprogs-git linux-apfs-rw-dkms-git
echo "Btrfs"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} btrfs-progs
echo "ext3 and ext4"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} e2fsprogs lib32-e2fsprogs
echo "exFAT"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} exfatprogs
echo "FAT12, FAT16, and FAT32"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} dosfstools
echo "HFS and HFS+"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} hfsprogs
echo "NTFS"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} ntfs-3g
echo "XFS"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} xfsprogs
echo "ZFS"
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} zfs-dkms zfs-utils
echo -e "apfs\nbtrfs\next4\nexfat\nfat\nhfs\nhfsplus\nntfs3\nzfs" > ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-file-systems.conf
echo "Installing additional file system support complete."

echo "Optimizing battery life..."
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} auto-cpufreq
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable auto-cpufreq
echo "Optimizing battery life complete."

echo "Minimizing writes to the disk..."
chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/systemd/journald.conf Journal Storage volatile
echo "vm.swappiness=10" >> ${WINESAPOS_INSTALL_DIR}/etc/sysctl.d/00-winesapos.conf
echo "Minimizing writes to the disk compelete."

echo "Setting up the desktop environment..."
# Install Xorg.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} xorg-server xorg-xinit xterm xf86-input-libinput
# Install Light Display Manager.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lightdm lightdm-gtk-greeter
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} lightdm-settings

if [[ "${WINESAPOS_AUTO_LOGIN}" == "true" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} groupadd --system autologin
    chroot ${WINESAPOS_INSTALL_DIR} gpasswd -a winesap autologin
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/lightdm/lightdm.conf SeatDefaults autologin-guest false
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/lightdm/lightdm.conf SeatDefaults autologin-guest false
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/lightdm/lightdm.conf SeatDefaults autologin-user winesap
    # Set a timeout to allow for changing the desktop environment or user.
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/lightdm/lightdm.conf SeatDefaults autologin-user-timeout 30
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    echo "Installing the Cinnamon desktop environment..."
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cinnamon
        # Text editor.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} xed

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cinnamon-sounds cinnamon-wallpapers manjaro-cinnamon-settings manjaro-settings-manager
        # Install Manjaro specific Cinnamon theme packages.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} adapta-maia-theme kvantum-manjaro
        # Image gallery.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} org.kde.pix
    else
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} org.kde.pix
    fi

    echo "Installing the Cinnamon desktop environment complete."
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    echo "Installing the KDE Plasma desktop environment..."
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} plasma-meta plasma-nm
    # Dolphin file manager and related plugins.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} dolphin ffmpegthumbs kdegraphics-thumbnailers konsole
    # Image gallery.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} org.kde.gwenview
    # Text editor.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} kate

    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
	# Note: 'manjaro-kde-settings' conflicts with 'steamdeck-kde-presets'.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} manjaro-kde-settings manjaro-settings-manager-kcm manjaro-settings-manager-knotifier
        # Install Manjaro specific KDE Plasma theme packages.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} breath-classic-icon-themes breath-wallpapers plasma5-themes-breath sddm-breath-theme
    fi

    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        # This hook is required to prevent Steam from launching during login.
        # https://github.com/LukeShortCloud/winesapOS/issues/242
        cp ../files/steamdeck-kde-presets.hook ${WINESAPOS_INSTALL_DIR}/usr/share/libalpm/hooks/
        # Vapor theme from Valve.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} steamdeck-kde-presets
    fi

    if [[ "${WINESAPOS_DISABLE_KWALLET}" == "true" ]]; then
        mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/
        touch ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/kwalletrc
        chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/.config/kwalletrc Wallet Enabled false
        chroot ${WINESAPOS_INSTALL_DIR} chown -R winesap.winesap /home/winesap/.config
    fi

    # Klipper cannot be fully disabled via the CLI so we limit this service as much as possible.
    # https://github.com/LukeShortCloud/winesapOS/issues/368
    if [[ "${WINESAPOS_ENABLE_KLIPPER}" == "false" ]]; then
        mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/
        mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.local/share/klipper
        touch ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/klipperrc
	# Clear out the history during logout.
        chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/.config/klipperrc General KeepClipboardContents false
	# Lower the number of items to keep in history from 20 down to 1.
        chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/.config/klipperrc General MaxClipItems 1
	# Allow password managers to set an empty clipboard.
        chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/.config/klipperrc General PreventEmptyClipboard false
        chroot ${WINESAPOS_INSTALL_DIR} chown -R winesap.winesap /home/winesap/.config
	# Ensure that the history is never saved to the local storage and only lives in RAM.
	echo 'ramfs    /home/winesap/.local/share/klipper    ramfs    rw,nosuid,nodev    0 0' >> ${WINESAPOS_INSTALL_DIR}/etc/fstab
    fi

    echo "Installing the KDE Plasma desktop environment complete."
fi

# Start LightDM. This will provide an option of which desktop environment to load.
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable lightdm
# Install Bluetooth.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} bluez bluez-utils blueman bluez-qt
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable bluetooth
## This is required to turn Bluetooth on or off.
chroot ${WINESAPOS_INSTALL_DIR} usermod -a -G rfkill winesap
# Install printer drivers.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cups libcups lib32-libcups bluez-cups cups-pdf usbutils
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable cups
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
echo "Setting up the desktop environment complete."

echo 'Setting up the "bauh" package manager...'
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} bauh snapd
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable snapd
clear_cache
echo 'Setting up the "bauh" package manager complete.'

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    echo "Installing gaming tools..."
    # Wine Staging.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} wine-staging
    # GameMode.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gamemode lib32-gamemode
    # Gamescope.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gamescope
    # MangoHUD.
    if [[ "${WINESAPOS_DISTRO}" == "steamos" ]]; then
        # MangoHUD is in the 'jupiter' repository.
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} mangohud lib32-mangohud
    else
        chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} mangohud lib32-mangohud
    fi
    # GOverlay.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} goverlay
    # ReplaySorcery.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} replay-sorcery
    # vkBasalt
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} vkbasalt lib32-vkbasalt
    # Prism Launcher for Minecraft.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} org.prismlauncher.PrismLauncher
    # Ludusavi.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} ludusavi
    # Lutris.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} lutris
    # Heoric Games Launcher (for Epic Games Store games).
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} heroic-games-launcher-bin
    # Steam dependencies.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb
    # Full installation of optional Wine dependencies.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} winetricks alsa-lib alsa-plugins cups giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 vkd3d vulkan-icd-loader wine_gecko wine-mono
    clear_cache
    # Protontricks.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} com.github.Matoking.protontricks
    ## Add a wrapper script so that the Flatpak can be used normally via the CLI.
    echo '#!/bin/bash
flatpak run com.github.Matoking.protontricks $@
' >> ${WINESAPOS_INSTALL_DIR}/usr/local/bin/protontricks
    chmod +x ${WINESAPOS_INSTALL_DIR}/usr/local/bin/protontricks
    # ProtonUp-Qt.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} net.davidotek.pupgui2
    # Bottles for running any Windows game or application.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} com.usebottles.bottles
    # Discord.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} com.discordapp.Discord
    # Open Broadcaster Software (OBS) Studio.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} com.obsproject.Studio
    # ZeroTier VPN.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} zerotier-one
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} zerotier-gui-git
    # AntiMicroX for configuring controller input.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_FLATPAK_INSTALL} io.github.antimicrox.antimicrox
    # game-devices-udev for more controller support.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} game-devices-udev
    echo "Installing gaming tools complete."
fi

echo "Setting up desktop shortcuts..."
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/appimagelauncher.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/appimagelauncher.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/bauh.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/blueman-manager.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/firefox-esr.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/terminator.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/nemo.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.kde.pix/current/active/export/share/applications/org.kde.pix.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/org.kde.dolphin.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.kde.gwenview/current/active/export/share/applications/org.kde.gwenview.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
fi

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    # AntiMicroX.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # Bottles.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.usebottles.bottles/current/active/export/share/applications/com.usebottles.bottles.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # Discord.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.discordapp.Discord/current/active/export/share/applications/com.discordapp.Discord.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # GOverlay.
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/io.github.benjamimgois.goverlay.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # Heroic Games Launcher.
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/heroic.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop
    sed -i s'/Exec=\/opt\/Heroic\/heroic\ \%U/Exec=\/usr\/bin\/gamemoderun \/opt\/Heroic\/heroic\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/heroic_games_launcher.desktop
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/heroic_games_launcher.desktop "Desktop Entry" Name "Heroic Games Launcher - GameMode"
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/net.lutris.Lutris.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop
    sed -i s'/Exec=lutris\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/lutris\ \%U/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/lutris.desktop
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/lutris.desktop "Desktop Entry" Name "Lutris - GameMode"
    # Ludusavi.
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/ludusavi.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # OBS.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.obsproject.Studio/current/active/export/share/applications/com.obsproject.Studio.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # Prism Launcher.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.prismlauncher.PrismLauncher/current/active/export/share/applications/org.prismlauncher.PrismLauncher.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    sed -i s'/Exec=\/usr\/bin\/flatpak/Exec=\/usr\/bin\/gamemoderun\ \/usr\/bin\/flatpak/'g ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/org.prismlauncher.PrismLauncher.desktop
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /home/winesap/Desktop/org.prismlauncher.PrismLauncher.desktop "Desktop Entry" Name "Prism Launcher - GameMode"
    # ProtonUp-Qt.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/net.davidotek.pupgui2/current/active/export/share/applications/net.davidotek.pupgui2.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # ZeroTier GUI.
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/zerotier-gui.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
fi

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    # Cheese.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.gnome.Cheese/current/active/export/share/applications/org.gnome.Cheese.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # ClamTk.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.gitlab.davem.ClamTk/current/active/export/share/applications/com.gitlab.davem.ClamTk.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/balena-etcher-electron.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # Flatseal.
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.github.tchx84.Flatseal/current/active/export/share/applications/com.github.tchx84.Flatseal.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    # GParted.
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/gparted.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.libreoffice.LibreOffice/current/active/export/share/applications/org.libreoffice.LibreOffice.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.keepassxc.KeePassXC/current/active/export/share/applications/org.keepassxc.KeePassXC.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/io.github.peazip.PeaZip/current/active/export/share/applications/io.github.peazip.PeaZip.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/qdirstat.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/shutter.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/com.transmissionbt.Transmission/current/active/export/share/applications/com.transmissionbt.Transmission.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/usr/share/applications/veracrypt.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
    cp ${WINESAPOS_INSTALL_DIR}/var/lib/flatpak/app/org.videolan.VLC/current/active/export/share/applications/org.videolan.VLC.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/
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
chroot ${WINESAPOS_INSTALL_DIR} git clone https://github.com/LukeShortCloud/snd_hda_macbookpro.git -b mac-linux-gaming-stick
chroot ${WINESAPOS_INSTALL_DIR} /bin/zsh snd_hda_macbookpro/install.cirrus.driver.sh
echo "snd-hda-codec-cirrus" >> ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-sound.conf
# Sound driver for Linux 5.15.
# https://github.com/LukeShortCloud/winesapOS/issues/152
chroot ${WINESAPOS_INSTALL_DIR} sh -c 'git clone https://github.com/egorenar/snd-hda-codec-cs8409.git;
  cd snd-hda-codec-cs8409;
  export KVER=$(ls -1 /lib/modules/ | grep -P "^5.15");
  make;
  make install'
echo "snd-hda-codec-cs8409" >> ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-sound.conf
# MacBook Pro Touch Bar driver.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} macbook12-spi-driver-dkms
sed -i s'/MODULES=(/MODULES=(applespi spi_pxa2xx_platform intel_lpss_pci apple_ibridge apple_ib_tb apple_ib_als /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf
# iOS device management via 'usbmuxd' and a workaround required for the Touch Bar to continue to work.
# 'uxbmuxd' and MacBook Pro Touch Bar bug reports:
# https://github.com/libimobiledevice/usbmuxd/issues/138
# https://github.com/roadrunner2/macbook12-spi-driver/issues/42
cp ../files/winesapos-touch-bar-usbmuxd-fix.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
cp ./winesapos-touch-bar-usbmuxd-fix.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable winesapos-touch-bar-usbmuxd-fix
# MacBook Pro >= 2018 require a special T2 Linux driver for the keyboard and mouse to work.
chroot ${WINESAPOS_INSTALL_DIR} git clone https://github.com/LukeShortCloud/mbp2018-bridge-drv --branch mac-linux-gaming-stick /usr/src/apple-bce-0.1

for kernel in $(ls -1 ${WINESAPOS_INSTALL_DIR}/usr/lib/modules/ | grep -P "^[0-9]+"); do
    # This will sometimes fail the first time it tries to install.
    chroot ${WINESAPOS_INSTALL_DIR} timeout 120s dkms install -m apple-bce -v 0.1 -k ${kernel}

    if [ $? -ne 0 ]; then
        chroot ${WINESAPOS_INSTALL_DIR} dkms install -m apple-bce -v 0.1 -k ${kernel}
    fi

done

sed -i s'/MODULES=(/MODULES=(apple-bce /'g ${WINESAPOS_INSTALL_DIR}/etc/mkinitcpio.conf

# Blacklist drives that are known to cause conflicts with the official Broadcom 'wl' driver.
echo -e "\nblacklist b43\nblacklist b43legacy\nblacklist bcm43xx\nblacklist bcma\nblacklist brcm80211\nblacklist brcmsmac\nblacklist brcmfmac\nblacklist brcmutil\nblacklist ndiswrapper\nblacklist ssb\nblacklist tg3\n" >> ${WINESAPOS_INSTALL_DIR}/etc/modprobe.d/winesapos.conf
# The 'wl' driver provides the best Broadcom support.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} broadcom-wl-dkms
echo "wl" >> ${WINESAPOS_INSTALL_DIR}/etc/modules-load.d/winesapos-wifi.conf

# mbpfan.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_YAY_INSTALL} mbpfan-git
chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/mbpfan.conf general min_fan_speed 1300
chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/mbpfan.conf general max_fan_speed 6200
chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/mbpfan.conf general max_temp 105
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable mbpfan
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

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Setting up the bootloader..."
    chroot ${WINESAPOS_INSTALL_DIR} mkinitcpio -p linux510 -p linux515
    # These two configuration lines allow the GRUB menu to show on boot.
    # https://github.com/LukeShortCloud/winesapOS/issues/41
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_TIMEOUT 10
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_TIMEOUT_STYLE menu

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
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_DISABLE_SUBMENU y
    # These two lines allow saving the selected kernel for next boot.
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_DEFAULT saved
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_SAVEDEFAULT true
    # Setup the GRUB theme.
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} grub-theme-vimix
    ## This theme needs to exist in the '/boot/' mount because if the root file system is encrypted, then the theme cannot be found.
    mkdir -p ${WINESAPOS_INSTALL_DIR}/boot/grub/themes/
    cp -R ${WINESAPOS_INSTALL_DIR}/usr/share/grub/themes/Vimix ${WINESAPOS_INSTALL_DIR}/boot/grub/themes/Vimix
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_THEME /boot/grub/themes/Vimix/theme.txt
    ## Target 720p for the GRUB menu as a minimum to support devices such as the GPD Win.
    ## https://github.com/LukeShortCloud/winesapOS/issues/327
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_GFXMODE 1280x720,auto
    ## Setting the GFX payload to 'text' instead 'keep' makes booting more reliable by supporting all graphics devices.
    ## https://github.com/LukeShortCloud/winesapOS/issues/327
    chroot ${WINESAPOS_INSTALL_DIR} crudini --set /etc/default/grub "" GRUB_GFXPAYLOAD_LINUX text
    # Remove the whitespace from the 'GRUB_* = ' lines that 'crudini' creates.
    sed -i -r "s/(\S*)\s*=\s*(.*)/\1=\2/g" ${WINESAPOS_INSTALL_DIR}/etc/default/grub

    chroot ${WINESAPOS_INSTALL_DIR} grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS --removable
    parted ${DEVICE} set 1 bios_grub on
    chroot ${WINESAPOS_INSTALL_DIR} grub-install --target=i386-pc ${DEVICE}

    if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
        sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="cryptdevice=LABEL=winesapos-luks:cryptroot root='$(echo ${root_partition} | sed -e s'/\//\\\//'g)' /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub
    fi

    # Configure higher polling frequencies for better compatibility with input devices.
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="usbhid.jspoll=1 usbhid.kbpoll=1 usbhid.mousepoll=1 /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub

    # Configure the "none" I/O scheduler for better performance on flash and SSD devices.
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="elevator=none /'g ${WINESAPOS_INSTALL_DIR}/etc/default/grub

    # Configure Arch Linux and SteamOS to load the Linux kernels in the correct order of newest to oldest.
    # This will make the newest kernel be bootable by default. For example, on Arch Linux 'linux' will be
    # the default over 'linux-lts' and on SteamOS 'linux-lts' will be the default over 'linux-steamos'.
    # https://github.com/LukeShortCloud/winesapOS/issues/144
    # https://github.com/LukeShortCloud/winesapOS/issues/325
    # https://github.com/LukeShortCloud/winesapOS/issues/489
    if [[ "${WINESAPOS_DISTRO_DETECTED}" != "manjaro" ]]; then
        sed -i s'/version_sort\ -r/sort/'g ${WINESAPOS_INSTALL_DIR}/etc/grub.d/10_linux
    fi

    chroot ${WINESAPOS_INSTALL_DIR} grub-mkconfig -o /boot/grub/grub.cfg
    echo "Setting up the bootloader complete."
fi

echo "Setting up root file system resize script..."
# This package provides the required 'growpart' command.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} cloud-guest-utils
# Copy from the current directory which should be "scripts".
cp ./winesapos-resize-root-file-system.sh ${WINESAPOS_INSTALL_DIR}/usr/local/bin/
cp ../files/winesapos-resize-root-file-system.service ${WINESAPOS_INSTALL_DIR}/etc/systemd/system/
chroot ${WINESAPOS_INSTALL_DIR} systemctl enable winesapos-resize-root-file-system
echo "Setting up root file system resize script complete."

echo "Setting up the first-time setup script..."
# winesapOS first-time setup script.
mkdir -p ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/ ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/autostart/
cp ./winesapos-setup.sh ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
cp ../files/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
ln -s /home/winesap/.winesapos/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.config/autostart/winesapos-setup.desktop
ln -s /home/winesap/.winesapos/winesapos-setup.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/winesapos-setup.desktop
## Install th required dependency for the setup script.
chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} kdialog
# winesapOS remote upgrade script.
cp ./winesapos-upgrade-remote-stable.sh ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
cp ../files/winesapos-upgrade.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/
ln -s /home/winesap/.winesapos/winesapos-upgrade.desktop ${WINESAPOS_INSTALL_DIR}/home/winesap/Desktop/winesapos-upgrade.desktop
# winesapOS icon used for both desktop shortcuts.
cp ../files/winesapos_logo_icon.png ${WINESAPOS_INSTALL_DIR}/home/winesap/.winesapos/winesapos_logo_icon.png
echo "Setting up the first-time setup script complete."

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Configuring Btrfs backup tools..."
    chroot ${WINESAPOS_INSTALL_DIR} ${CMD_PACMAN_INSTALL} grub-btrfs snapper snap-pac
    cp ../files/etc-snapper-configs-root ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/root
    cp ../files/etc-snapper-configs-root ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/home
    sed -i s'/SUBVOLUME=.*/SUBVOLUME=\"\/home\"/'g ${WINESAPOS_INSTALL_DIR}/etc/snapper/configs/home
    chroot ${WINESAPOS_INSTALL_DIR} chown -R root.root /etc/snapper/configs
    btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/.snapshots
    btrfs subvolume create ${WINESAPOS_INSTALL_DIR}/home/.snapshots
    # Ensure the new "root" and "home" configurations will be loaded.
    sed -i s'/SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"root home\"/'g ${WINESAPOS_INSTALL_DIR}/etc/conf.d/snapper
    chroot ${WINESAPOS_INSTALL_DIR} systemctl enable snapper-timeline.timer snapper-cleanup.timer
    echo "Configuring Btrfs backup tools complete."
fi

echo "Resetting the machine-id file..."
echo -n | tee ${WINESAPOS_INSTALL_DIR}/etc/machine-id
rm -f ${WINESAPOS_INSTALL_DIR}/var/lib/dbus/machine-id
chroot ${WINESAPOS_INSTALL_DIR} ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Resetting the machine-id file complete."

echo "Setting up winesapOS files..."
mkdir ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
cp ../VERSION ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
echo "${WINESAPOS_IMAGE_TYPE}" > ${WINESAPOS_INSTALL_DIR}/etc/winesapos/IMAGE_TYPE
cp /tmp/winesapos-install.log ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
# Continue to log to the file after it has been copied over.
exec > >(tee -a ${WINESAPOS_INSTALL_DIR}/etc/winesapos/winesapos-install.log) 2>&1
echo "Setting up winesapOS files complete."

echo "Cleaning up..."

# Temporarily add write permissions back to the file so we can modify it.
chmod 0644 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap

if [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "false" ]]; then
    echo "Require the 'winesap' user to enter a password when using sudo..."
    echo "winesap ALL=(root) ALL" > ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    # This command is required for the user 'winesapos-mute.service'.
    echo "winesap ALL=(root) NOPASSWD: /usr/bin/dmidecode" >> ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
    echo "Require the 'winesap' user to enter a password when using sudo complete."
fi

# "sudo" defaults to a 15 minute timeout for when the user password needs to be provided again.
# This provides a problem for automated first-time setup and upgrade scripts on the secure image.
# Set the timeout to infinity (no timeout) by using a negative number.
# "sudo" also only allows 3 failed passwords before locking a user out from running privileged commands
# for a short period of time. Increase that to 20 tries to allow users to figure out their password.
echo "Defaults:winesap passwd_tries=20,timestamp_timeout=-1" >> ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap
chmod 0440 ${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/winesap

chown -R 1000.1000 ${WINESAPOS_INSTALL_DIR}/home/winesap
# Secure this directory as it contains the verbose build log.
chmod 0700 ${WINESAPOS_INSTALL_DIR}/etc/winesapos/
clear_cache
echo "Cleaning up complete."

if [[ "${WINESAPOS_PASSWD_EXPIRE}" == "true" ]]; then

    for u in root winesap; do
        echo -n "Setting the password for ${u} to expire..."
        chroot ${WINESAPOS_INSTALL_DIR} passwd --expire ${u}
        echo "Done."
    done

fi

echo "Populating trusted Pacman keyrings..."
chroot ${WINESAPOS_INSTALL_DIR} pacman-key --refresh-keys

if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    chroot ${WINESAPOS_INSTALL_DIR} pacman-key --populate archlinux manjaro
else
    # SteamOS does not provide GPG keys so only update the Arch Linux keyring.
    chroot ${WINESAPOS_INSTALL_DIR} pacman-key --populate archlinux
fi

echo "Populating trusted Pacman keyrings done."

if [ -n "${WINESAPOS_HTTP_PROXY_CA}" ]; then
    echo "Removing the proxy certificate authority from the chroot..."
    rm -f ${WINESAPOS_INSTALL_DIR}/etc/ca-certificates/trust-source/anchors/$(echo ${WINESAPOS_HTTP_PROXY_CA} | grep -o -P '[^\/]*$')
    chroot ${WINESAPOS_INSTALL_DIR} update-ca-trust
    echo "Removing the proxy certificate authority from the chroot complete."
fi

echo "Defragmenting Btrfs root file system..."
btrfs filesystem defragment -r ${WINESAPOS_INSTALL_DIR}
echo "Defragmenting Btrfs root file system complete."

echo "Syncing files to disk..."
sync
echo "Syncing files to disk complete."

echo "Running tests..."
zsh ./winesapos-tests.sh
echo "Running tests complete."

echo "Done."
echo "End time: $(date)"
