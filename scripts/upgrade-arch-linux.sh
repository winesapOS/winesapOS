#!/bin/zsh

echo "Running 2.0.0 to 2.1.0 upgrades..."

echo "Upgrading '/home/' to be a Btrfs subvolume..."
btrfs subvolume list / | grep -q -P " home$"
if [ ! $? -eq 0 ]; then
    echo "Btrfs subvolume for '/home/' does not exist. Creating..."
    mv /home /homeUPGRADE
    btrfs subvolume create /home
    root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')
    mount -t btrfs -o subvol=/home,noatime,nodiratime ${root_partition} /home
    pacman -S --noconfirm arch-install-scripts
    genfstab -U / | grep "/home" >> /etc/fstab
    rsync -aurvP /homeUPGRADE/ /home/
    echo "Please manually delete '/homeUPGRADE/' after confirming all files are now in '/home/'."
else
    echo "Btrfs subvolume for '/home/' already exists. Skipping."
fi
echo "Upgrading '/home/' to be a Btrfs subvolume complete."

echo "Running 2.0.0 to 2.1.0 upgrades complete."
