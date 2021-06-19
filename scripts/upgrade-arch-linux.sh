#!/bin/zsh

echo "Running 2.0.0 to 2.1.0 upgrades..."

echo "Upgrading '/home/' to be a Btrfs subvolume..."
btrfs subvolume list / | grep -q -P " home$"
if [ ! $? -eq 0 ]; then
    echo "Btrfs subvolume for '/home/' does not exist. Creating..."
    mv /home /homeUPGRADE
    btrfs subvolume create /home
    root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')
    mount -t btrfs -o subvol=/home,noatime,nodiratime,compress-force=zstd:1,discard ${root_partition} /home
    pacman -S --noconfirm arch-install-scripts
    genfstab -U / | grep "/home" >> /etc/fstab
    rsync -aurvP /homeUPGRADE/ /home/
    echo "Please manually delete '/homeUPGRADE/' after confirming all files are now in '/home/'."
else
    echo "Btrfs subvolume for '/home/' already exists. Skipping."
fi
echo "Upgrading '/home/' to be a Btrfs subvolume complete."

echo "Upgrading Btrfs mounts to use compression and TRIM..."
mount | grep "on / type btrfs" | grep -q "compress-force=zstd:1,discard"
if [ ! $? -eq 0 ]; then
    echo "The mount options are not in use. Creating..."
    pacman -S --noconfirm arch-install-scripts
    mount -o remount,compress-force=zstd:1,discard /
    # Compress existing files.
    btrfs filesystem defrag -c -r /
    # Delete the original root mount in /etc/fstab.
    sed -i '/\s\/\s/d' /etc/fstab
    # Create the new root mount in /etc/fstab.
    genfstab -U / | grep -P "\s+/\s+btrfs" >> /etc/fstab
else
    echo "The mount options are in use. Skipping."
fi

echo "Upgrading Btrfs mounts to use compression and TRIM complete."

echo "Running 2.0.0 to 2.1.0 upgrades complete."
