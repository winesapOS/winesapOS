#!/bin/bash

DEVICE=/dev/vda

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
mkswap /dev/vda3
mkfs -t btrfs ${DEVICE}4
echo "Creating partitions complete."

echo "Mounting partitions..."
mount -t btrfs -o subvol=/ /dev/vda4 /mnt
mkdir -p /mnt/boot/efi
mount -t vfat /dev/vda2 /mnt/boot/efi
mkdir -p /mnt/tmp /mnt/var/log /mnt/var/tmp

for i in tmp var/log var/tmp; do
    mkdir -p /mnt/${i}
    mount ramfs -t ramfs -o nodev,nosuid /mnt/{$i}
done

echo "Mounting partitions complete."

echo "Saving partition mounts to /etc/fstab..."
pacman -S -y
# Required for the 'genfstab' tool.
pacman --noconfirm -S arch-install-scripts
genfstab -U -P /mnt > /mnt/etc/fstab
echo "Saving partition mounts to /etc/fstab complete."

echo "Installing Manjaro..."
basestrap /mnt base efibootmgr grub linux510 mkinitcpio nano networkmanager sudo vim
manjaro-chroot /mnt systemctl enable NetworkManager
manjaro-chroot /mnt systemctl enable systemd-timesyncd
echo "Installing Manjaro complete."

echo "Configuring user accounts..."
echo -e "root\nroot" | passwd root
manjaro-chroot /mnt useradd stick
echo -e "stick\nstick" | passwd stick
echo "stick ALL=(root) NOPASSWD:ALL" > /mnt/etc/sudoers.d/stick
chmod 0440 /mnt/etc/sudoers.d/stick
echo "Configuring user accounts complete."

echo "Installing gaming tools..."
# Lutris.
pacman --noconfirm -S lutris
# Steam.
pacman --noconfirm -S gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb steam-manjaro steam-native
# Wine.
pacman --noconfirm -S wine-staging winetricks alsa-lib alsa-plugins cups dosbox giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-v4l-utils lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libpulse libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 v4l-utils vkd3d vulkan-icd-loader wine_gecko wine-mono
echo "Installing gaming tools complete."

echo "Setting up the Cinnamon desktop environment..."
# Install Xorg.
manjaro-chroot /mnt pacman --noconfirm -S xorg-server lib32-mesa mesa xorg-server xorg-xinit xterm xf86-input-libinput xf86-video-amdgpu xf86-video-intel xf86-video-nouveau
# Install Light Display Manager.
manjaro-chroot /mnt pacman --noconfirm -S lightdm lightdm-gtk-greeter lightdm-settings
# Install Cinnamon.
manjaro-chroot /mnt pacman --noconfirm -S cinnamon cinnamon-sounds cinnamon-wallpapers manjaro-cinnamon-settings
# Install Manjaro specific Cinnamon theme packages.
manjaro-chroot /mnt pacman --noconfirm -S adapta-maia-theme kvantum-manjaro manjaro-cinnamon-settings
# Start LightDM. This will provide an option of which desktop environment to load.
manjaro-chroot /mnt systemctl enable lightdm
echo "Setting up the Cinnamon desktop environment complete."

echo "Setting up the bootloader..."
manjaro-chroot /mnt  mkinitcpio -p linux510
manjaro-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Manjaro
parted ${DEVICE} set 1 bios_grub on
manjaro-chroot /mnt grub-install --target=i386-pc ${DEVICE}
echo "Setting up the bootloader complete."

echo "Cleaning up and syncing files to disk..."
manjaro-chroot /mnt pacman --noconfirm -S -c -c
sync
echo "Cleaning up and syncing files to disk complete."

echo "Done."
