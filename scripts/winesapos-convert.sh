#!/bin/bash
# Script by @GuestSneezeOSDev
echo "Convering system to winesapOS in 3"
sleep 1
echo "Convering system to winesapOS in 2"
sleep 1
echo "Convering system to winesapOS in 1"
sleep 1
echo "System is converting ..."
pacman -Sy --noconfirm
useradd -m winesap
echo "winesap:winesap" | chpasswd
pacman -S git wget flatpak base-devel --noconfirm
curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/os-release-winesapos --location --output /usr/lib/os-release-winesapos
ln -s /usr/lib/os-release-winesapos /etc/os-release-winesapos

echo "[winesapos]" >> /etc/pacman.conf
echo "Server = https://winesapos.lukeshort.cloud/repo/winesapos/\$arch/" >> /etc/pacman.conf
echo "Importing the public GPG key for the winesapOS repository..."
chroot ${WINESAPOS_INSTALL_DIR} pacman-key --recv-keys 1805E886BECCCEA99EDF55F081CA29E4A4B01239
chroot ${WINESAPOS_INSTALL_DIR} pacman-key --init
chroot ${WINESAPOS_INSTALL_DIR} pacman-key --lsign-key 1805E886BECCCEA99EDF55F081CA29E4A4B01239
echo "Importing the public GPG key for the winesapOS repository complete."
echo "Adding the winesapOS repository complete."
grep pacman_install scripts/winesapos-install.sh
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
yay -S --noconfirm waydroid waydroid-biglinux waydroid-image waydroid-image-gapps waydroid-image-halium waydroid-magisk waydroid-openrc google-chrome protonup-qt heroic-games-launcher heroic-games-launcher-bin prismlauncher prismlauncher-bin lutris-wine-meta
flatpak install --noninteractive io.github.antimicrox.antimicrox com.usebottles.bottles com.calibre_ebook.calibre org.gnome.Cheese com.gitlab.davem.ClamTk com.discordapp.Discord org.filezillaproject.Filezilla com.github.tchx84.Flatseal org.freedesktop.Platform.VulkanLayer.gamescope com.google.Chrome com.heroicgameslauncher.hgl org.keepassxc.KeePassXC org.libreoffice.LibreOffice net.lutris.Lutris org.freedesktop.Platform.VulkanLayer.MangoHud com.obsproject.Studio io.github.peazip.PeaZip org.prismlauncher.PrismLauncher com.github.Matoking.protontricks net.davidotek.pupgui2 org.qbittorrent.qBittorrent com.valvesoftware.Steam com.valvesoftware.Steam.Utility.steamtinkerlaunch org.videolan.VLC
echo "System is converting ... Conversion completed successfully"
