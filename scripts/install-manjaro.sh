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
sync
echo "Installing Manjaro complete."

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

echo "Done."
