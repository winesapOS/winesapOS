#!/bin/bash
# Script originally created by @GuestSneezeOSDev
echo "Converting system to winesapOS in 3"
sleep 1
echo "Converting system to winesapOS in 2"
sleep 1
echo "Converting system to winesapOS in 1"
sleep 1
echo "System is converting ..."

flatpak_install_all() {
  flatpak install -y --noninteractive \
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
}

WINESAPOS_DISTRO_DETECTED=$(grep -P '^ID=' /etc/os-release | cut -d= -f2)
if [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]] || [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
    echo "Arch Linux or Manjaro detected. winesapOS conversion will attempt to install all packages."
    pacman -S -y
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
      appimagepool-appimage \
      auto-cpufreq \
      apfsprogs-git \
      bauh \
      ceph-libs-bin \
      ceph-bin \
      coolercontrol \
      crudini \
      fatx \
      firefox-esr \
      game-devices-udev \
      gamescope-session-git \
      gamescope-session-steam-git \
      gfs2-utils \
      goverlay-git \
      hfsprogs \
      krathalans-apparmor-profiles-git \
      linux-apfs-rw-dkms-git \
      linux-fsync-nobara-bin \
      ludusavi \
      mangohud-git \
      lib32-mangohud-git \
      oh-my-zsh-git \
      opengamepadui-bin \
      opengamepadui-session-git \
      oversteer \
      pacman-static \
      paru \
      polychromatic \
      python-iniparse-git \
      qdirstat \
      reiserfs-defrag \
      replay-sorcery-git \
      snapd \
      ssdfs-tools \
      steamtinkerlaunch \
      tzupdate \
      vkbasalt \
      lib32-vkbasalt \
      waydroid \
      waydroid-image-gapps \
      xone-dkms-git \
      yay \
      zerotier-gui-git \
      zfs-dkms \
      zfs-utils

    flatpak_install_all
else
    echo "Not Arch Linux or Manjaro. winesapOS conversion will only attempt to install Flatpaks."
    flatpak_install_all
fi

echo "Conversion to winesapOS completed successfully"
