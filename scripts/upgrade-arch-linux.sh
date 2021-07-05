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

echo "Upgrading Linux kernels by adding Linux LTS 5.4..."
ls /usr/lib/modules/ | grep -q -P "^5\.4\."
if [ ! $? -eq 0 ]; then
    echo "Linux 5.4 is not installed. Installing..."
    pacman -S --noconfirm linux54 linux54-headers
else
    echo "Linux 5.4 is installed. Skipping."
fi
echo "Upgrading Linux kernels by adding Linux LTS 5.4 complete."

echo "Upgrading Mac drivers..."
dkms remove -m apple-bce -v 0.1 --all
rm -rf /usr/src/apple-bce-0.1
git clone https://github.com/ekultails/mbp2018-bridge-drv --branch mac-linux-gaming-stick /usr/src/apple-bce-0.1
dkms install -m apple-bce -v 0.1 -k $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+")
echo "Upgrading Mac drivers complete."

echo "Upgrading GRUB menu..."
grep -q -P "^GRUB_TIMEOUT_STYLE=menu" /etc/default/grub
if [ $? -eq 0 ]; then
    echo "GRUB menu is not hidden. Skipping."
else
    echo "GRUB menu is hidden. Exposing..."
    sed -i s'/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/'g /etc/default/grub
    sed -i s'/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/'g /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
fi
echo "Upgrading GRUB menu complete."

echo "Running 2.0.0 to 2.1.0 upgrades complete."
