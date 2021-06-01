#!/bin/bash

DEVICE=/dev/vda
CMD_PACMAN_INSTALL="/usr/bin/pacman --noconfirm -S --needed"

lscpu | grep "Hypervisor vendor:"
if [ $? -ne 0 ]
then
    echo "This build is not running in a virtual machine. Exiting to be safe."
    exit 1
fi

echo "Wiping partition table..."
# Wipe the partition table.
# This is used to make testing faster and easier by having the installation start from scratch.
umount /mnt/boot/efi
umount /mnt
dd if=/dev/zero of=${DEVICE} bs=1M count=10
sync
partprobe
echo "Wiping partition table complete."

echo "Creating partitions..."
# GPT is required for UEFI boot.
parted ${DEVICE} mklabel gpt
# An empty partition is required for BIOS boot backwards compatibility.
parted ${DEVICE} mkpart primary 2048s 2M
# EFI partition.
parted ${DEVICE} mkpart primary fat32 2M 500M
parted ${DEVICE} set 2 boot on
parted ${DEVICE} set 2 esp on
# 8 GB swap partition.
parted ${DEVICE} mkpart primary linux-swap 500M 8500M
parted ${DEVICE} set 3 swap on
# Root partition uses the rest of the space.
parted ${DEVICE} mkpart primary btrfs 8500M 100%
# Formatting via 'parted' does not work.
# We need to reformat it those partitions.
mkfs -t vfat ${DEVICE}2
mkswap ${DEVICE}3
mkfs -t btrfs ${DEVICE}4
echo "Creating partitions complete."

echo "Mounting partitions..."
mount -t btrfs -o subvol=/,noatime,nodiratime ${DEVICE}4 /mnt
mkdir -p /mnt/boot/efi
mount -t vfat ${DEVICE}2 /mnt/boot/efi
swapon ${DEVICE}3

for i in tmp var/log var/tmp; do
    mkdir -p /mnt/${i}
    mount ramfs -t ramfs -o nodev,nosuid /mnt/${i}
done

echo "Mounting partitions complete."

echo "Setting up fastest pacman mirror on live media..."
pacman-mirrors --api --protocol https --country United_States
pacman -S -y
echo "Setting up fastest pacman mirror on live media complete."

echo "Installing Manjaro..."
basestrap /mnt base btrfs-progs efibootmgr grub linux510 mkinitcpio networkmanager
manjaro-chroot /mnt systemctl enable NetworkManager systemd-timesyncd
sed -i s'/MODULES=(/MODULES=(btrfs\ /'g /mnt/etc/mkinitcpio.conf
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
manjaro-chroot /mnt locale-gen
echo "Installing Manjaro complete."

echo "Saving partition mounts to /etc/fstab..."
# Required for the 'genfstab' tool.
${CMD_PACMAN_INSTALL} arch-install-scripts
genfstab -U -P /mnt > /mnt/etc/fstab
echo "Saving partition mounts to /etc/fstab complete."

echo "Configuring fastest mirror in the chroot..."
cp ../files/pacman-mirrors.service /mnt/etc/systemd/system/
# Enable on first boot.
manjaro-chroot /mnt systemctl enable pacman-mirrors
# Temporarily set mirrors to United States to use during the build process.
manjaro-chroot /mnt pacman-mirrors --api --protocol https --country United_States
echo "Configuring fastest mirror in the chroot complete."

echo "Installing additional packages..."
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} clamav curl ffmpeg firefox jre8-openjdk libdvdcss lm_sensors man-db mlocate nano ncdu nmap oh-my-zsh openssh python python-pip rsync sudo terminator tmate wget vim vlc zerotier-one zsh zstd
# Development packages required for building other packages.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} binutils dkms fakeroot gcc git make
echo "Installing additional packages complete."

echo "Optimizing battery life..."
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} auto-cpufreq tlp
manjaro-chroot /mnt systemctl enable auto-cpufreq tlp
echo "Optimizing battery life complete."

echo "Configuring user accounts..."
echo -e "root\nroot" | manjaro-chroot /mnt passwd root
manjaro-chroot /mnt useradd --create-home stick
echo -e "stick\nstick" | manjaro-chroot /mnt passwd stick
echo "stick ALL=(root) NOPASSWD:ALL" > /mnt/etc/sudoers.d/stick
chmod 0440 /mnt/etc/sudoers.d/stick
echo "Configuring user accounts complete."

echo "Installing the 'yay' AUR package manager..."
export YAY_VER="10.2.2"
wget https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz
tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
mv yay_${YAY_VER}_x86_64/yay /mnt/usr/bin/yay
rm -rf ./yay*
echo "Installing the 'yay' AUR package manager complete."

echo "Installing additional packages from the AUR..."
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S crudini freeoffice google-chrome hfsprogs qdirstat
echo "Installing additional packages from the AUR complete."

echo "Minimizing writes to the disk..."
manjaro-chroot /mnt crudini --set /etc/systemd/journald.conf Journal Storage volatile
echo "vm.swappiness=10" >> /mnt/etc/sysctl.d/00-mac-linux-gaming-stick.conf
echo "Minimizing writes to the disk compelete."

echo "Installing gaming tools..."
# Vulkan drivers.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} vulkan-intel lib32-vulkan-intel vulkan-radeon lib32-vulkan-radeon
# GameMode.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} gamemode lib32-gamemode
# Lutris.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} lutris
# Steam.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb steam-manjaro steam-native
# Wine.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} wine-staging winetricks alsa-lib alsa-plugins cups dosbox giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-v4l-utils lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libpulse libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 v4l-utils vkd3d vulkan-icd-loader wine_gecko wine-mono
echo "Installing gaming tools complete."

echo "Setting up the Cinnamon desktop environment..."
# Install Xorg.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} xorg-server lib32-mesa mesa xorg-server xorg-xinit xterm xf86-input-libinput xf86-video-amdgpu xf86-video-intel xf86-video-nouveau
# Install Light Display Manager.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} lightdm lightdm-gtk-greeter lightdm-settings
# Install Cinnamon.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} cinnamon cinnamon-sounds cinnamon-wallpapers manjaro-cinnamon-settings
# Install Manjaro specific Cinnamon theme packages.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} adapta-maia-theme kvantum-manjaro manjaro-cinnamon-settings manjaro-settings-manager
# Start LightDM. This will provide an option of which desktop environment to load.
manjaro-chroot /mnt systemctl enable lightdm
echo "Setting up the Cinnamon desktop environment complete."

echo "Setting up Mac drivers..."
# Sound driver.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} linux510-headers
manjaro-chroot /mnt git clone https://github.com/ekultails/snd_hda_macbookpro.git -b mac-linux-gaming-stick
manjaro-chroot /mnt snd_hda_macbookpro/install.cirrus.driver.sh
echo "snd-hda-codec-cirrus" >> /mnt/etc/modules-load.d/mac-linux-gaming-stick.conf
# MacBook Pro touchbar driver.
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S macbook12-spi-driver-dkms
sed -i s'/MODULES=(/MODULES=(applespi spi_pxa2xx_platform intel_lpss_pci apple_ibridge apple_ib_tb apple_ib_als /'g /mnt/etc/mkinitcpio.conf
# MacBook Pro >= 2018 require a special T2 Linux driver for the keyboard and mouse to work.
manjaro-chroot /mnt git clone https://github.com/marcosfad/mbp2018-bridge-drv --branch aur /usr/src/apple-bce-0.1
manjaro-chroot /mnt dkms install -m apple-bce -v 0.1 -k $(ls -1 /mnt/usr/lib/modules/ | grep -P "^[0-9]+")
sed -i s'/MODULES=(/MODULES=(apple-bce /'g /mnt/etc/mkinitcpio.conf
# Blacklist Mac WiFi drivers are these are known to be unreliable.
echo -e "\nblacklist brcmfmac\nblacklist brcmutil" >> /mnt/etc/modprobe.d/mac-linux-gaming-stick.conf
echo "Setting up Mac drivers complete."

echo "Setting up the bootloader..."
manjaro-chroot /mnt mkinitcpio -p linux510
sed -i s'/GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=false/'g /mnt/etc/default/grub
sed -i s'/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/'g /mnt/etc/default/grub
manjaro-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Manjaro --removable
parted ${DEVICE} set 1 bios_grub on
manjaro-chroot /mnt grub-install --target=i386-pc ${DEVICE}
manjaro-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo "Setting up the bootloader complete."

echo "Setting up root file system resize script..."
# This package provides the required 'growpart' command.
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S cloud-guest-utils
# Copy from the current directory which should be "scripts".
cp resize-root-file-system.sh /mnt/usr/local/bin/
cp ../files/resize-root-file-system.service /mnt/etc/systemd/system/
manjaro-chroot /mnt systemctl enable resize-root-file-system
echo "Setting up root file system resize script complete."

echo "Configuring Btrfs backup tools..."
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} grub-btrfs snapper snap-pac
cp ../files/etc-snapper-configs-root /mnt/etc/snapper/configs/root
manjaro-chroot /mnt chown root.root /etc/snapper/configs/root
btrfs subvolume create /mnt/.snapshots
# Ensure the new "root" configuration will be loaded.
sed -i s'/SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"root\"/'g /mnt/etc/conf.d/snapper
manjaro-chroot /mnt systemctl enable snapper-timeline.timer snapper-cleanup.timer
echo "Configuring Btrfs backup tools complete."

echo "Cleaning up and syncing files to disk..."
manjaro-chroot /mnt pacman --noconfirm -S -c -c
rm -rf /mnt/var/cache/pacman/pkg/*
# The 'mirrorlist' file will be regenerated by the 'pacman-mirrors.service'.
> /mnt/etc/pacman.d/mirrorlist
sync
echo "Cleaning up and syncing files to disk complete."

echo "Done."
