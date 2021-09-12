#!/bin/zsh

set -x
# Log both the standard output and error from this script to a log file.
exec > >(tee /tmp/install-manjaro.log) 2>&1
echo "Start time: $(date)"

MLGS_ENCRYPT="${MLGS_ENCRYPT:-false}"
MLGS_DEVICE="${MLGS_DEVICE:-vda}"
DEVICE="/dev/${MLGS_DEVICE}"
CMD_PACMAN_INSTALL="/usr/bin/pacman --noconfirm -S --needed"

lscpu | grep "Hypervisor vendor:"
if [ $? -ne 0 ]
then
    echo "This build is not running in a virtual machine. Exiting to be safe."
    exit 1
fi

echo "Creating partitions..."
# GPT is required for UEFI boot.
parted ${DEVICE} mklabel gpt
# An empty partition is required for BIOS boot backwards compatibility.
parted ${DEVICE} mkpart primary 2048s 2M
# exFAT partition for generic flash drive storage.
parted ${DEVICE} mkpart primary 2M 16G
# EFI partition.
parted ${DEVICE} mkpart primary fat32 16G 16.5G
parted ${DEVICE} set 3 boot on
parted ${DEVICE} set 3 esp on
# Boot partition.
parted ${DEVICE} mkpart primary ext4 16.5G 17.5G
# Root partition uses the rest of the space.
parted ${DEVICE} mkpart primary btrfs 17.5G 100%
# Formatting via 'parted' does not work so we need to reformat those partitions again.
mkfs -t exfat ${DEVICE}2
exfatlabel ${DEVICE}2 mlgs-drive
mkfs -t vfat ${DEVICE}3
# FAT32 file systems require upper-case labels.
fatlabel ${DEVICE}3 MLGS-EFI
mkfs -t ext4 ${DEVICE}4
e2label ${DEVICE}4 mlgs-boot

if [[ "${MLGS_ENCRYPT}" == "true" ]]; then
    echo "password" | cryptsetup -q luksFormat ${DEVICE}5
    echo "password" | cryptsetup luksOpen ${DEVICE}5 cryptroot
    root_partition="/dev/mapper/cryptroot"
else
    root_partition="${DEVICE}5"
fi

mkfs -t btrfs ${root_partition}
btrfs filesystem label ${root_partition} mlgs-root
echo "Creating partitions complete."

echo "Mounting partitions..."
mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt
btrfs subvolume create /mnt/home
mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt/home
btrfs subvolume create /mnt/swap
mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} /mnt/swap
mkdir /mnt/boot
mount -t ext4 ${DEVICE}4 /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat ${DEVICE}3 /mnt/boot/efi

for i in tmp var/log var/tmp; do
    mkdir -p /mnt/${i}
    mount ramfs -t ramfs -o nodev,nosuid /mnt/${i}
done

echo "Mounting partitions complete."

echo "Configuring swap file..."
# Disable the usage of swap in the live media environment.
echo 0 > /proc/sys/vm/swappiness
touch /mnt/swap/swapfile
# Avoid Btrfs copy-on-write.
chattr +C /mnt/swap/swapfile
# Now fill in the 2 GiB swap file.
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=2000
# A swap file requires strict permissions to work.
chmod 0600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swaplabel --label mlgs-swap /mnt/swap/swapfile
swapon /mnt/swap/swapfile
echo "Configuring swap file complete."

echo "Setting up fastest pacman mirror on live media..."
pacman-mirrors --api --protocol https --country United_States
pacman -S -y
echo "Setting up fastest pacman mirror on live media complete."

echo "Setting up Pacman parallel package downloads on live media..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g /etc/pacman.conf
echo "Setting up Pacman parallel package downloads on live media complete."

echo "Installing Manjaro..."
basestrap /mnt base btrfs-progs efibootmgr exfat-utils grub linux54 linux510 mkinitcpio networkmanager
manjaro-chroot /mnt systemctl enable NetworkManager systemd-timesyncd
sed -i s'/MODULES=(/MODULES=(btrfs\ /'g /mnt/etc/mkinitcpio.conf
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
manjaro-chroot /mnt locale-gen
echo "Installing Manjaro complete."

echo "Setting up Pacman parallel package downloads in chroot..."
# Increase from the default 1 package download at a time to 5.
sed -i s'/\#ParallelDownloads.*/ParallelDownloads=5/'g /mnt/etc/pacman.conf
echo "Setting up Pacman parallel package downloads in chroot complete."

echo "Saving partition mounts to /etc/fstab..."
partprobe
# Required for the 'genfstab' tool.
/usr/bin/pacman --noconfirm -S --needed arch-install-scripts
genfstab -L -P /mnt > /mnt/etc/fstab
echo "Saving partition mounts to /etc/fstab complete."

echo "Configuring fastest mirror in the chroot..."
cp ../files/pacman-mirrors.service /mnt/etc/systemd/system/
# Enable on first boot.
manjaro-chroot /mnt systemctl enable pacman-mirrors
# Temporarily set mirrors to United States to use during the build process.
manjaro-chroot /mnt pacman-mirrors --api --protocol https --country United_States
echo "Configuring fastest mirror in the chroot complete."

echo "Installing additional packages..."
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} clamav curl ffmpeg firefox jre8-openjdk libdvdcss lm_sensors man-db mlocate nano ncdu nmap openssh python python-pip rsync smartmontools sudo terminator tmate wget vim vlc zerotier-one zstd
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

echo "Installing Oh My Zsh..."
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} oh-my-zsh zsh
cp /mnt/usr/share/oh-my-zsh/zshrc /mnt/home/stick/.zshrc
chown manjaro: /mnt/home/stick/.zshrc
echo "Installing Oh My Zsh complete."

echo "Installing the 'yay' AUR package manager..."
export YAY_VER="10.3.0"
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
# Heoric Games Launcher (for Epic Games Store games).
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S heroic-games-launcher-bin
# Steam.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} gcc-libs libgpg-error libva libxcb lib32-gcc-libs lib32-libgpg-error lib32-libva lib32-libxcb steam-manjaro steam-native
# Wine.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} wine-staging winetricks alsa-lib alsa-plugins cups dosbox giflib gnutls gsm gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libva lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-sdl2 lib32-v4l-utils lib32-vkd3d lib32-vulkan-icd-loader libgphoto2 libjpeg-turbo libldap libpng libpulse libva libxcomposite libxinerama libxslt mpg123 ncurses openal opencl-icd-loader samba sane sdl2 v4l-utils vkd3d vulkan-icd-loader wine_gecko wine-mono
# protontricks. 'wine-staging' is installed first because otherwise 'protontricks' depends on 'winetricks' which depends on 'wine' by default.
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S protontricks
# Proton GE for Steam.
wget https://raw.githubusercontent.com/toazd/ge-install-manager/master/ge-install-manager -O /mnt/usr/local/bin/ge-install-manager
chmod +x /mnt/usr/local/bin/ge-install-manager
# The '/tmp/' directory will not work as a 'tmp_path' for 'ge-install-manager' due to a
# bug relating to calculating storage space on ephemeral file systems. As a workaround,
# we use '/home/stick/tmp' as the temporary path.
# https://github.com/toazd/ge-install-manager/issues/3
mkdir -p /mnt/home/stick/tmp /mnt/home/stick/.config/ge-install-manager/ /mnt/home/stick/.local/share/Steam/compatibilitytools.d/
cp ../files/ge-install-manager.conf /mnt/home/stick/.config/ge-install-manager/
chown -R manjaro: /mnt/home/stick/tmp /mnt/home/stick/.config /mnt/home/stick/.local
manjaro-chroot /mnt sudo -u stick ge-install-manager -i Proton-6.5-GE-2
rm -f /mnt/home/stick/.local/share/Steam/compatibilitytools.d/Proton-*.tar.gz
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
# Install Bluetooth.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} blueberry
## This is required to turn Bluetooth on or off.
manjaro-chroot /mnt usermod -a -G rfkill stick
# Install sound drivers.
## Alsa
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} alsa-lib lib32-alsa-lib alsa-plugins lib32-alsa-plugins alsa-utils
## PusleAudio
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} pulseaudio lib32-pulseaudio pulseaudio-alsa pavucontrol
# Lower the first sound device volume to 0% to prevent loud start-up sounds on Macs.
mkdir -p /mnt/home/stick/.config/pulse
cat << EOF > /mnt/home/stick/.config/pulse/default.pa
.include /etc/pulse/default.pa
# 25%
#set-sink-volume 0 16384
# 0%
set-sink-volume 0 0
EOF
chown -R manjaro: /mnt/home/stick/.config
# Install printer drivers.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} cups libcups lib32-libcups bluez-cups cups-pdf usbutils
manjaro-chroot /mnt systemctl enable cups
echo "Setting up the Cinnamon desktop environment complete."

echo "Setting up desktop shortcuts..."
mkdir /mnt/home/stick/Desktop
cp /mnt/usr/share/applications/heroic.desktop /mnt/home/stick/Desktop/heroic_games_launcher.desktop
sed -i s'/Exec=\/opt\/Heroic\/heroic\ \%U/Exec=\/usr\/bin\/gamemoderun \/opt\/Heroic\/heroic\ \%U/'g /mnt/home/stick/Desktop/heroic_games_launcher.desktop
manjaro-chroot /mnt crudini --set /home/stick/Desktop/heroic_games_launcher.desktop "Desktop Entry" Name "Heroic Games Launcher - GameMode"
cp /mnt/usr/share/applications/net.lutris.Lutris.desktop /mnt/home/stick/Desktop/lutris.desktop
sed -i s'/Exec=lutris\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/lutris\ \%U/'g /mnt/home/stick/Desktop/lutris.desktop
manjaro-chroot /mnt crudini --set /home/stick/Desktop/lutris.desktop "Desktop Entry" Name "Lutris - GameMode"
cp /mnt/usr/share/applications/steam-native.desktop /mnt/home/stick/Desktop/steam_native.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-native\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam\-native\ \%U/'g /mnt/home/stick/Desktop/steam_native.desktop
manjaro-chroot /mnt crudini --set /home/stick/Desktop/steam_native.desktop "Desktop Entry" Name "Steam (Native) - GameMode"
cp /mnt/usr/share/applications/steam.desktop /mnt/home/stick/Desktop/steam_runtime.desktop
sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/gamemoderun \/usr\/bin\/steam-runtime\ \%U/'g /mnt/home/stick/Desktop/steam_runtime.desktop
# Use 'arch-chroot' instead of 'manjaro-chroot' due to the better arguments quote handling.
# https://github.com/ekultails/mac-linux-gaming-stick/issues/114
arch-chroot /mnt crudini --set /home/stick/Desktop/steam_runtime.desktop "Desktop Entry" Name "Steam (Runtime) - GameMode"
cp /mnt/usr/share/applications/freeoffice-*.desktop /mnt/home/stick/Desktop/
cp /mnt/usr/share/applications/google-chrome.desktop /mnt/home/stick/Desktop/
cp /mnt/usr/share/applications/qdirstat.desktop /mnt/home/stick/Desktop/
# Fix permissions on the desktop shortcuts.
chmod +x /mnt/home/stick/Desktop/*.desktop
chown -R manjaro: /mnt/home/stick/Desktop
echo "Setting up desktop shortcuts complete."

echo "Setting up Mac drivers..."
# Sound driver.
manjaro-chroot /mnt ${CMD_PACMAN_INSTALL} linux54-headers linux510-headers
manjaro-chroot /mnt git clone https://github.com/ekultails/snd_hda_macbookpro.git -b mac-linux-gaming-stick
manjaro-chroot /mnt snd_hda_macbookpro/install.cirrus.driver.sh
echo "snd-hda-codec-cirrus" >> /mnt/etc/modules-load.d/mac-linux-gaming-stick.conf
# MacBook Pro touchbar driver.
manjaro-chroot /mnt sudo -u stick yay --noconfirm -S macbook12-spi-driver-dkms
sed -i s'/MODULES=(/MODULES=(applespi spi_pxa2xx_platform intel_lpss_pci apple_ibridge apple_ib_tb apple_ib_als /'g /mnt/etc/mkinitcpio.conf
# iOS device management via 'usbmuxd' and a workaround required for the Touch Bar to continue to work.
# 'uxbmuxd' and MacBook Pro Touch Bar bug reports:
# https://github.com/libimobiledevice/usbmuxd/issues/138
# https://github.com/roadrunner2/macbook12-spi-driver/issues/42
cp ../files/touch-bar-usbmuxd-fix.service /mnt/etc/systemd/system/
manjaro-chroot /mnt systemctl enable touch-bar-usbmuxd-fix
# MacBook Pro >= 2018 require a special T2 Linux driver for the keyboard and mouse to work.
manjaro-chroot /mnt git clone https://github.com/ekultails/mbp2018-bridge-drv --branch mac-linux-gaming-stick /usr/src/apple-bce-0.1

for kernel in $(ls -1 /mnt/usr/lib/modules/ | grep -P "^[0-9]+"); do
    # This will sometimes fail the first time it tries to install.
    manjaro-chroot /mnt timeout 120s dkms install -m apple-bce -v 0.1 -k ${kernel}

    if [ $? -ne 0 ]; then
        manjaro-chroot /mnt dkms install -m apple-bce -v 0.1 -k ${kernel}
    fi

done

sed -i s'/MODULES=(/MODULES=(apple-bce /'g /mnt/etc/mkinitcpio.conf
# Blacklist Mac WiFi drivers are these are known to be unreliable.
echo -e "\nblacklist brcmfmac\nblacklist brcmutil" >> /mnt/etc/modprobe.d/mac-linux-gaming-stick.conf
echo "Setting up Mac drivers complete."

echo "Setting mkinitcpio modules and hooks order..."
# Required fix for:
# https://github.com/ekultails/mac-linux-gaming-stick/issues/94
# Also added 'keymap' and 'encrypt' for LUKS encryption support.
sed -i s'/HOOKS=.*/HOOKS=(base udev block keyboard keymap autodetect modconf encrypt filesystems fsck)/'g /mnt/etc/mkinitcpio.conf
echo "Setting mkinitcpio modules and hooks order complete."

echo "Setting up the bootloader..."
manjaro-chroot /mnt mkinitcpio -p linux54 -p linux510
# These two configuration lines solve the error: "error: sparse file not allowed."
# https://github.com/ekultails/mac-linux-gaming-stick/issues/27
sed -i s'/GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=false/'g /mnt/etc/default/grub
sed -i s'/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/'g /mnt/etc/default/grub
# These two configuration lines allow the GRUB menu to show on boot.
# https://github.com/ekultails/mac-linux-gaming-stick/issues/41
sed -i s'/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/'g /mnt/etc/default/grub
sed -i s'/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/'g /mnt/etc/default/grub
manjaro-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Manjaro --removable
parted ${DEVICE} set 1 bios_grub on
manjaro-chroot /mnt grub-install --target=i386-pc ${DEVICE}

if [[ "${MLGS_ENCRYPT}" == "true" ]]; then
    sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="cryptdevice=UUID='$(lsblk -o name,UUID | grep ${MLGS_DEVICE}5 | awk '{print $2}')':cryptroot root='$(echo ${root_partition} | sed -e s'/\//\\\//'g)' /'g /mnt/etc/default/grub
fi

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
cp ../files/etc-snapper-configs-root /mnt/etc/snapper/configs/home
sed -i s'/SUBVOLUME=.*/SUBVOLUME=\"\/home\"/'g /mnt/etc/snapper/configs/home
manjaro-chroot /mnt chown -R root.root /etc/snapper/configs/*
btrfs subvolume create /mnt/.snapshots
btrfs subvolume create /mnt/home/.snapshots
# Ensure the new "root" and "home" configurations will be loaded.
sed -i s'/SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"root home\"/'g /mnt/etc/conf.d/snapper
manjaro-chroot /mnt systemctl enable snapper-timeline.timer snapper-cleanup.timer
echo "Configuring Btrfs backup tools complete."

echo "Resetting the machine-id file..."
echo -n | tee /mnt/etc/machine-id
rm -f /mnt/var/lib/dbus/machine-id
manjaro-chroot /mnt ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Resetting the machine-id file complete."

echo "Setting up Mac Linux Gaming Stick files..."
mkdir /mnt/etc/mac-linux-gaming-stick/
cp ../VERSION /mnt/etc/mac-linux-gaming-stick/
cp /tmp/install-manjaro.log /mnt/etc/mac-linux-gaming-stick/
# Continue to log to the file after it has been copied over.
exec > >(tee -a /mnt/etc/mac-linux-gaming-stick/install-manjaro.log) 2>&1
echo "Setting up Mac Linux Gaming Stick files complete."

echo "Cleaning up and syncing files to disk..."
manjaro-chroot /mnt pacman --noconfirm -S -c -c
rm -rf /mnt/var/cache/pacman/pkg/*
# The 'mirrorlist' file will be regenerated by the 'pacman-mirrors.service'.
truncate -s 0 /mnt/etc/pacman.d/mirrorlist
sync
echo "Cleaning up and syncing files to disk complete."

echo "Running tests..."
zsh ./tests-arch-linux.sh
echo "Running tests complete."

echo "Done."
echo "End time: $(date)"
