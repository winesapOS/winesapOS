#!/bin/zsh

if [[ "${WINESAPOS_DEBUG}" == "true" ]]; then
    set -x
fi

START_TIME=$(date --iso-8601=seconds)
exec > >(tee /etc/winesapos/upgrade_${START_TIME}.log) 2>&1
echo "Start time: ${START_TIME}"

VERSION_NEW="2.2.0"

# Update the repository cache.
pacman -Sy
# Update the trusted repository keyrings.
pacman --noconfirm -S archlinux-keyring manjaro-keyring

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
    btrfs subvolume create /home/.snapshots
    cp /etc/snapper/configs/root /etc/snapper/configs/home
    sed -i s'/SUBVOLUME=.*/SUBVOLUME=\"\/home\"/'g /etc/snapper/configs/home
    sed -i s'/SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS=\"root home\"/'g /etc/conf.d/snapper
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
if [[ "$(cat /etc/winesapos/VERSION)" == "2.0.0" ]];
    then echo "Installing new 'apple-bce' driver..."
    dkms remove -m apple-bce -v 0.1 --all
    rm -rf /usr/src/apple-bce-0.1
    git clone https://github.com/LukeShortCloud/mbp2018-bridge-drv --branch winesapos /usr/src/apple-bce-0.1
    dkms install -m apple-bce -v 0.1 -k $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+")
else
    echo "Skipping installing 'apple-bce' (winesapOS '2.0.0' detected)."
fi
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

echo "Upgrading packages..."
echo "Installing Heroic Games Launcher for Epic Games Store games if needed..."
sudo -u winesap yay --noconfirm -S --needed heroic-games-launcher-bin
echo "Installing 'smartmontools' if needed..."
pacman -S --needed --noconfirm smartmontools
echo "Upgrading packages complete."

echo "Upgrading desktop shortcuts..."
if [ ! -f /home/winesap/Desktop/heroic_games_launcher.desktop ]; then
    cp /usr/share/applications/heroic.desktop /home/winesap/Desktop/heroic_games_launcher.desktop
    sed -i s'/Exec=\/opt\/Heroic\/heroic\ \%U/Exec=\/usr\/bin\/gamemoderun \/opt\/Heroic\/heroic\ \%U/'g /home/winesap/Desktop/heroic_games_launcher.desktop
    crudini --set /home/winesap/Desktop/heroic_games_launcher.desktop "Desktop Entry" Name "Heroic Games Launcher - GameMode"
fi
if [ ! -f /home/winesap/Desktop/lutris.desktop ]; then
    cp /usr/share/applications/net.lutris.Lutris.desktop /home/winesap/Desktop/lutris.desktop
    sed -i s'/Exec=lutris\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/lutris\ \%U/'g /home/winesap/Desktop/lutris.desktop
    crudini --set /home/winesap/Desktop/lutris.desktop "Desktop Entry" Name "Lutris - GameMode"
fi
if [ ! -f /home/winesap/Desktop/steam_native.desktop ]; then
    cp /usr/share/applications/steam-native.desktop /home/winesap/Desktop/steam_native.desktop
    sed -i s'/Exec=\/usr\/bin\/steam\-native\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam\-native\ \%U/'g /home/winesap/Desktop/steam_native.desktop
    crudini --set /home/winesap/Desktop/steam_native.desktop "Desktop Entry" Name "Steam (Native) - GameMode"
fi
if [ ! -f /home/winesap/Desktop/steam_runtime.desktop ]; then
    cp /usr/lib/steam/steam.desktop /home/winesap/Desktop/steam_runtime.desktop
    sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam-runtime\ \%U/'g /home/winesap/Desktop/steam_runtime.desktop
    crudini --set /home/winesap/Desktop/steam_runtime.desktop "Desktop Entry" Name "Steam (Runtime) - GameMode"
fi

for i in \
  freeoffice-planmaker.desktop \
  freeoffice-presentations.desktop \
  freeoffice-textmaker.desktop
    do if [ ! -f "/home/winesap/Desktop/${i}" ]; then
        cp "/usr/share/applications/${i}" "/home/winesap/Desktop/${i}"
    fi
done

if [ ! -f /home/winesap/Desktop/google-chrome.desktop ]; then
    cp /usr/share/applications/google-chrome.desktop /home/winesap/Desktop/
fi
if [ ! -f /home/winesap/Desktop/qdirstat.desktop ]; then
    cp /usr/share/applications/qdirstat.desktop /home/winesap/Desktop/
fi
# Fix permissions on the desktop shortcuts.
chmod +x /home/winesap/Desktop/*.desktop
chown -R winesap: /home/winesap/Desktop/*.desktop
echo "Upgrading desktop shortcuts complete."

echo "Uprading by adding Proton GE..."
ls -1 /home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^Proton.*GE.*"
if [ $? -eq 0 ]; then
    echo "Proton GE already installed. Skipping."
else
    echo "Proton GE not installed. Installing now..."
    wget https://raw.githubusercontent.com/toazd/ge-install-manager/master/ge-install-manager -O /usr/local/bin/ge-install-manager
    chmod +x /usr/local/bin/ge-install-manager
    # The '/tmp/' directory will not work as a 'tmp_path' for 'ge-install-manager' due to a
    # bug relating to calculating storage space on ephemeral file systems. As a workaround,
    # we use '/home/winesap/tmp' as the temporary path.
    # https://github.com/toazd/ge-install-manager/issues/3
    mkdir -p /home/winesap/tmp/ /home/winesap/.config/ge-install-manager/ /home/winesap/.steam/root/compatibilitytools.d/
    cp ../files/ge-install-manager.conf /home/winesap/.config/ge-install-manager/
    chown -R winesap: /home/winesap/tmp /home/winesap/.config /home/winesap/.steam
    sudo -u winesap ge-install-manager -i Proton-6.5-GE-2
fi
echo "Uprading by adding Proton GE complete."

echo "Upgrading by adding 'protontricks' program..."
if [ -f /usr/bin/protontricks ]; then
    echo "'protontricks' is already installed. Skipping."
else
    echo "'protontricks' was not found. Installing now..."
    sudo -u winesap yay --noconfirm -S --needed protontricks
fi
echo "Upgrading by adding 'protontricks' program complete."

echo "Upgrading by adding printer drivers..."
if [ -f /etc/systemd/system/printer.target.wants/cups.service ]; then
    echo "Printer drivers already installed. Skipping."
else
    echo "Printer not installed. Installing now..."
    pacman -S --needed --noconfirm cups libcups lib32-libcups bluez-cups cups-pdf usbutils
    systemctl enable cups
fi
echo "Upgrading by adding printer drivers complete."

echo "Running 2.0.0 to 2.1.0 upgrades complete."

echo "Upgrading mkinitcpio modules and hooks order..."
grep -q "HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)" /etc/mkinitcpio.conf
if [ $? -eq 0 ]; then
    echo "mkinitcptio modules and hooks order is correct. Skipping."
else
    echo "mkinitcptio modules and hooks order is not correct. Updating..."
    sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)/'g /etc/mkinitcpio.conf

    for kernel in $(ls -1 /etc/mkinitcpio.d/ | cut -d. -f1)
        do mkinitcpio -p ${kernel}
    done

fi
echo "Upgrading mkinitcpio modules and hooks order complete."

echo "Upgrading Pacman parallel package downloads..."
crudini --set /etc/pacman.conf options ParallelDownloads 5
echo "Upgrading Pacman parallel package downloads complete."

echo "Upgrading to add webcam software (Cheese) if needed..."
pacman --noconfirm -S --needed cheese
echo "Upgrading to add webcam software (Cheese) complete."

echo "Upgrading to add screenshot software (Shutter) if needed..."
pacman --noconfirm -S --needed shutter
echo "Upgrading to add screenshot software (Shutter) complete."

echo "Running 2.1.0 to 2.2.0 upgrades complete."

# Record the original and new versions.
echo "VERSION_ORIGNIAL=$(cat /etc/winesapos/VERSION),VERSION_NEW=${VERSION_NEW},DATE=${START_TIME}" >> /etc/winesapos/UPGRADED

echo "Done."
echo "End time: $(date --iso-8601=seconds)"
