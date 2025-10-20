#!/bin/bash
# Script originally created by @GuestSneezeOSDev

set -x

echo "System is converting ..."

CMD_PACMAN_INSTALL=(sudo pacman --noconfirm -S --needed)

flatpak_install_all() {
    # Unlike the Pacman packages, do not exit as failed due to false-positive errors such as:
    # Error: Failed to install com.google.Chrome: While trying to apply extra data: apply_extra script failed, exit status 256
    sudo flatpak install -y --noninteractive \
      io.github.antimicrox.antimicrox \
      com.usebottles.bottles \
      com.calibre_ebook.calibre \
      org.gnome.Cheese \
      com.gitlab.davem.ClamTk \
      com.discordapp.Discord \
      org.filezillaproject.Filezilla \
      com.github.tchx84.Flatseal \
      com.google.Chrome \
      com.heroicgameslauncher.hgl \
      org.kde.kalk \
      org.keepassxc.KeePassXC \
      org.libreoffice.LibreOffice \
      net.lutris.Lutris \
      runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08 \
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
    sudo pacman -S -y
    "${CMD_PACMAN_INSTALL[@]}" base-devel flatpak git
    sudo curl --location https://raw.githubusercontent.com/winesapOS/winesapOS/main/files/os-release-winesapos --output /usr/lib/os-release-winesapos
    sudo ln -s /usr/lib/os-release-winesapos /etc/os-release-winesapos

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "arch" ]]; then
        if ! grep -q -P "^\[multilib\]" /etc/pacman.conf; then
            echo "Adding the 32-bit multilb repository..."
            # 32-bit multilib libraries.
            echo -e '\n\n[multilib]\nInclude=/etc/pacman.d/mirrorlist' | sudo tee -a /etc/pacman.conf
            sudo pacman -S -y
            echo "Adding the 32-bit multilb repository complete."
        fi
    fi

    if ! grep -q "\[winesapos\]" /etc/pacman.conf; then
        echo "Adding the winesapOS repository..."
        echo "[winesapos-rolling]" | sudo tee -a /etc/pacman.conf
        echo "Server = https://winesapos.lukeshort.cloud/repo/winesapos/\$arch/" | sudo tee -a /etc/pacman.conf
        echo "Importing the public GPG key for the winesapOS repository..."
        sudo pacman-key --recv-keys 1805E886BECCCEA99EDF55F081CA29E4A4B01239
        sudo pacman-key --init
        sudo pacman-key --lsign-key 1805E886BECCCEA99EDF55F081CA29E4A4B01239
        echo "Importing the public GPG key for the winesapOS repository complete."
        sudo pacman -S -y
        echo "Adding the winesapOS repository complete."
    fi

    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        # https://aur.chaotic.cx/
        echo "Adding the Chaotic AUR repository..."
        sudo pacman-key --recv-keys 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo curl --location --remote-name 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --output-dir /tmp/
        sudo pacman --noconfirm -U /tmp/chaotic-keyring.pkg.tar.zst
        sudo curl --location --remote-name 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --output-dir /tmp/
        sudo pacman --noconfirm -U /tmp/chaotic-mirrorlist.pkg.tar.zst
        sudo rm -f /tmp/chaotic-*.pkg.tar.zst
        echo "
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
        sudo pacman -S -y
        echo "Adding the Chaotic AUR repository complete."
    fi

    echo "Upgrading all system packages..."
    sudo pacman -S -u --noconfirm
    echo "Upgrading all system packages complete."

    echo "Installing all AUR packages..."
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit 1
    makepkg -si --noconfirm
    # shellcheck disable=SC2103
    cd ..
    sudo rm -rf yay
    # GuestSneezeOSDev: Balena Etcher time
    export ETCHER_VER="1.19.25"
    curl --location "https://github.com/balena-io/etcher/releases/download/v${ETCHER_VER}/balenaEtcher-${ETCHER_VER}-x64.AppImage" --output /home/"${USER}"/Desktop/balenaEtcher.AppImage
    chmod +x /home/"${USER}"/Desktop/balenaEtcher.AppImage

    if ! yay --noconfirm -S --needed --removemake \
      appimagepool-appimage \
      apfsprogs-git \
      bauh \
      bcachefs-dkms \
      bcachefs-tools \
      ceph-libs-bin \
      ceph-bin \
      coolercontrol \
      crudini \
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
      rar \
      reiserfsprogs \
      remoteplaywhatever \
      snapd \
      ssdfs-tools \
      steamtinkerlaunch-git \
      tlp \
      tzupdate \
      umu-launcher \
      vkbasalt \
      lib32-vkbasalt \
      waydroid \
      waydroid-image-gapps \
      xone-dkms-git \
      yay \
      zerotier-gui-git \
      zfs-dkms \
      zfs-utils; then
        echo "Failed to install all Flatpaks during the winesapOS conversion."
        exit 1
    else
        echo "Installing all AUR packages complete."
    fi

    flatpak_install_all
else
    echo "Not Arch Linux or Manjaro. winesapOS conversion will only attempt to install Flatpaks."
    flatpak_install_all
fi

echo "Conversion to winesapOS completed successfully"
