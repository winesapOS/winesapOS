#!/bin/bash
# WinesapDualboot repo has been discountinued but the scripts work just fine
# WinesapDualboot is licenced under GPLv3
sudo mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /
sudo btrfs subvolume create /mnt/.snapshots
sudo btrfs subvolume create /mnt/home
sudo mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /mnt/home
sudo btrfs subvolume create /mnt/home/.snapshots
sudo btrfs subvolume create /mnt/swap
sudo mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /mnt/swap
sudo mkdir /mnt/boot
sudo mount --label winesapos-boot0 /mnt/boot
sudo mkdir /mnt/boot/efi
sudo mount /dev/sdb /mnt/boot/efi

# This part downloads tars
sudo tar --extract --keep-old-files --verbose --file /run/media/winesap/wos-drive/winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst --directory /mnt/

# Configure mr bootloader
grep -v -P "winesapos|WOS" /mnt/etc/fstab | sudo tee /mnt/etc/fstab
genfstab -L /mnt | sudo tee -a /mnt/etc/fstab
sudo mount --rbind /dev /mnt/dev
sudo mount --rbind /sys /mnt/sys
sudo mount -t proc /proc /mnt/proc
sudo chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS
sudo chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
sudo chroot /mnt mkinitcpio -P
sudo sync
