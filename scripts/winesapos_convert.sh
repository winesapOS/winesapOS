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
wget https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.1.0/_test/winesapos-4.1.0-beta.1-minimal-rootfs.tar.zst
pacman -U --noconfirm winesapos-4.1.0-beta.1-minimal-rootfs.tar.zst
rm *.zst
touch /etc/os-release-winesapos
echo 'NAME="winesapOS"' >> /etc/os-release-winesapos
echo 'PRETTY_NAME="winesapOS"' >> /etc/os-release-winesapos
echo 'ID=winesapOS' >> /etc/os-release-winesapos
echo 'ID_LIKE=arch' >> /etc/os-release-winesapos
echo 'VERSION_ID=4.1.0-beta.3' >> /etc/os-release-winesapos
echo 'HOME_URL="https://github.com/LukeShortCloud/winesapOS"' >> /etc/os-release-winesapos
echo 'SUPPORT_URL="https://github.com/LukeShortCloud/winesapOS/issues"' >> /etc/os-release-winesapos
echo 'BUG_REPORT_URL="https://github.com/LukeShortCloud/winesapOS/issues"' >> /etc/os-release-winesapos
echo "[jupiter-staging]" >> /etc/pacman.conf
echo "Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/\$repo/os/\$arch" >> /etc/pacman.conf
echo "SigLevel = Never" >> /etc/pacman.conf
echo "[winesapos]" >> /etc/pacman.conf
echo "Server = https://winesapos.lukeshort.cloud/repo/winesapos/\$arch/" >> /etc/pacman.conf
echo "SigLevel = Never" >> /etc/pacman.conf
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
yay -S --noconfirm waydroid waydroid-biglinux waydroid-image waydroid-image-gapps waydroid-image-halium waydroid-magisk waydroid-openrc google-chrome protonup-qt heroic-games-launcher heroic-games-launcher-bin prismlauncher prismlauncher-bin lutris-wine-meta
flatpak install --noninteractive io.github.antimicrox.antimicrox com.usebottles.bottles com.calibre_ebook.calibre org.gnome.Cheese com.gitlab.davem.ClamTk com.discordapp.Discord org.filezillaproject.Filezilla com.github.tchx84.Flatseal org.freedesktop.Platform.VulkanLayer.gamescope com.google.Chrome com.heroicgameslauncher.hgl org.keepassxc.KeePassXC org.libreoffice.LibreOffice net.lutris.Lutris org.freedesktop.Platform.VulkanLayer.MangoHud com.obsproject.Studio io.github.peazip.PeaZip org.prismlauncher.PrismLauncher com.github.Matoking.protontricks net.davidotek.pupgui2 org.qbittorrent.qBittorrent com.valvesoftware.Steam com.valvesoftware.Steam.Utility.steamtinkerlaunch org.videolan.VLC
echo "System is converting ... Conversion completed successfully"
