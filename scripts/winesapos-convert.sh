#!/bin/bash
# Script originally created by @GuestSneezeOSDev
echo "Converting system to winesapOS in 3"
sleep 1
echo "Converting system to winesapOS in 2"
sleep 1
echo "Converting system to winesapOS in 1"
sleep 1
echo "System is converting ..."
pacman -S -y
useradd -m winesap
echo "winesap:winesap" | chpasswd
pacman -S git wget flatpak base-devel --noconfirm
curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/files/os-release-winesapos --location --output /usr/lib/os-release-winesapos
ln -s /usr/lib/os-release-winesapos /etc/os-release-winesapos

grep "[winesapos]" /etc/pacman.conf
if [ $? -ne 0 ]; then
    echo "Adding the winesapOS repository..."
    echo "[winesapos]" >> /etc/pacman.conf
    echo "Server = https://winesapos.lukeshort.cloud/repo/winesapos/\$arch/" >> /etc/pacman.conf
    echo "Importing the public GPG key for the winesapOS repository..."
    pacman-key --recv-keys 1805E886BECCCEA99EDF55F081CA29E4A4B01239
    pacman-key --init
    pacman-key --lsign-key 1805E886BECCCEA99EDF55F081CA29E4A4B01239
    echo "Importing the public GPG key for the winesapOS repository complete."
    pacman -S -y
    echo "Adding the winesapOS repository complete."
fi

grep "[chaotic-aur]" /etc/pacman.conf
if [ $? -ne 0 ]; then
    # https://aur.chaotic.cx/
    echo "Adding the Chaotic AUR repository..."
    pacman-key --recv-keys 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    wget 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' -LO /tmp/chaotic-keyring.pkg.tar.zst
    pacman --noconfirm -U /tmp/chaotic-keyring.pkg.tar.zst
    wget 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' -LO /tmp/chaotic-mirrorlist.pkg.tar.zst
    pacman --noconfirm -U /chaotic-mirrorlist.pkg.tar.zst
    rm -f /tmp/chaotic-*.pkg.tar.zst
    echo "
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
    pacman -S -y
    echo "Adding the Chaotic AUR repository complete."
fi

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
yay -S --noconfirm \
  google-chrome \
  heroic-games-launcher \
  heroic-games-launcher-bin \
  lutris-wine-meta \
  prismlauncher \
  prismlauncher-bin \
  protonup-qt \
  waydroid \
  waydroid-biglinux \
  waydroid-image \
  waydroid-image-gapps \
  waydroid-image-halium \
  waydroid-magisk \
  waydroid-openrc

flatpak install --noninteractive \
  io.github.antimicrox.antimicrox \
  com.usebottles.bottles \
  com.calibre_ebook.calibre \
  org.gnome.Cheese \
  com.gitlab.davem.ClamTk \
  com.discordapp.Discord \
  org.filezillaproject.Filezilla \
  com.github.tchx84.Flatseal \
  org.freedesktop.Platform.VulkanLayer.gamescope \
  com.google.Chrome \
  com.heroicgameslauncher.hgl \
  org.keepassxc.KeePassXC \
  org.libreoffice.LibreOffice \
  net.lutris.Lutris \
  org.freedesktop.Platform.VulkanLayer.MangoHud \
  com.obsproject.Studio \
  io.github.peazip.PeaZip \
  org.prismlauncher.PrismLauncher \
  com.github.Matoking.protontricks \
  net.davidotek.pupgui2 \
  org.qbittorrent.qBittorrent \
  com.valvesoftware.Steam \
  com.valvesoftware.Steam.Utility.steamtinkerlaunch \
  org.videolan.VLC

echo "Conversion to winesapOS completed successfully"
