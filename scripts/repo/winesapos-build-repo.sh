#!/bin/sh

set -x

WORK_DIR="${WORK_DIR:-/tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(yay --noconfirm -S --removemake)
echo 'MAKEFLAGS="-j $(nproc)"' | sudo tee -a /etc/makepkg.conf

sudo pacman -S -y -y --noconfirm

# Install yay for helping install AUR build dependencies.
sudo -E ${CMD_PACMAN_INSTALL[*]} base-devel binutils curl dkms git make tar wget
export YAY_VER="11.1.2"
curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
sudo mv yay_${YAY_VER}_x86_64/yay /usr/bin/yay
rm -rf ./yay*

# Paru.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# bauh.
## snapd dependency for bauh.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/snapd.git
cd snapd
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
## bauh
cd ${WORK_DIR}
git clone https://aur.archlinux.org/bauh.git
cd bauh
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# krathalans-apparmor-profiles-git.
gpg --recv-keys C0F9AEE56E47D174
cd ${WORK_DIR}
git clone https://aur.archlinux.org/krathalans-apparmor-profiles-git.git
cd krathalans-apparmor-profiles-git
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# crudini.
## python-iniparse dependency for crudini.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/python-iniparse.git
cd python-iniparse
### This dependency needs to be installed to build crudini.
makepkg -s --noconfirm -i
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
## crudini.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/crudini.git
cd crudini
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# APFS support.
## apfsprogs-git.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/apfsprogs-git.git
cd apfsprogs-git
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
## linux-apfs-rw-dkms-git.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/linux-apfs-rw-dkms-git.git
cd linux-apfs-rw-dkms-git
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# HFS programs.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/hfsprogs.git
cd hfsprogs
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# ZFS support.
## zfs-utils dependency for zfs-dkms.
gpg --recv-keys 6AD860EED4598027
cd ${WORK_DIR}
git clone https://aur.archlinux.org/zfs-utils.git
cd zfs-utils
### This dependency needs to be installed to build crudini.
makepkg -s --noconfirm -i
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
## zfs-dkms.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/zfs-dkms.git
cd zfs-dkms
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Etcher.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/etcher-bin.git
cd etcher-bin
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Firefox Extended Support Release (ESR)
cd ${WORK_DIR}
git clone https://aur.archlinux.org/firefox-esr-bin.git
cd firefox-esr-bin
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# QDirStat.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/qdirstat.git
cd qdirstat
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Oh My Zsh.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/oh-my-zsh-git.git
cd oh-my-zsh-git
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# auto-cpufreq.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/auto-cpufreq.git
cd auto-cpufreq
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# LightDM Settings.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/lightdm-settings.git
cd lightdm-settings
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# MangoHud.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/mangohud.git
cd mangohud
## The mangohud-common (built from the mangohud PKGBUILD) needs to be installed first to build lib32-mangohud.
makepkg -s --noconfirm -i
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
cd ${WORK_DIR}
git clone https://aur.archlinux.org/lib32-mangohud.git
cd lib32-mangohud
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# GOverlay.
## This is built after MangoHud because it is a dependency.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/goverlay.git
cd goverlay
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# ReplaySorcery (optional dependency of MangoHud).
cd ${WORK_DIR}
git clone https://aur.archlinux.org/replay-sorcery.git
cd replay-sorcery
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# vkBasalt (optional dependency of MangoHud).
## vkbasalt.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/vkbasalt.git
cd vkbasalt
makepkg -s --noconfirm -i
cp ./*.pkg.tar.zst ${OUTPUT_DIR}
## lib32-vkbasalt.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/lib32-vkbasalt.git
cd lib32-vkbasalt
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Ludusavi.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/ludusavi.git
cd ludusavi
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Heroic Games Launcher.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/heroic-games-launcher-bin.git
cd heroic-games-launcher-bin
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# ZeroTier-GUI.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/zerotier-gui-git.git
cd zerotier-gui-git
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# MacBook SPI Driver.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/macbook12-spi-driver-dkms.git
cd macbook12-spi-driver-dkms
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Mesa 64-bit.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/mesa-steamos.git
cd mesa-steamos
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Mesa 32-bit.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/lib32-mesa-steamos.git
cd lib32-mesa-steamos
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

# Linux Neptune.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/linux-steamos.git
cd linux-steamos
## SteamOS 3 uses older Arch Linux packages so 'gcc11' does not exist yet.
## Instead, use 'gcc' which is actually GCC 11.
sed -i s'/gcc11/gcc/'g PKGBUILD
sed -i s'/gcc-11/gcc/'g PKGBUILD
sed -i s'/g++-11/g++/'g PKGBUILD
makepkg -s --noconfirm
cp ./*.pkg.tar.zst ${OUTPUT_DIR}

WINESAPOS_REPO_BUILD_LINUX_GIT="${WINESAPOS_REPO_BUILD_LINUX_GIT:-false}"
if [[ "${WINESAPOS_REPO_BUILD_LINUX_GIT}" == "true" ]]; then
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/linux-git.git
    cd linux-git
    makepkg -s --noconfirm
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
fi

WINESAPOS_REPO_BUILD_MESA_GIT="${WINESAPOS_REPO_BUILD_MESA_GIT:-false}"
if [[ "${WINESAPOS_REPO_BUILD_MESA_GIT}" == "true" ]]; then
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/mesa-git.git
    cd mesa-git
    makepkg -s --noconfirm
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/lib32-mesa-git.git
    cd mesa-git
    makepkg -s --noconfirm
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
fi

# Build Pacman repository metadata.
WINESAPOS_REPO_BUILD_TESTING="${WINESAPOS_REPO_BUILD_TESTING:-false}"
if [[ "${WINESAPOS_REPO_BUILD_TESTING}" == "true" ]]; then
    repo-add ${OUTPUT_DIR}/winesapos-testing.db.tar.gz ${OUTPUT_DIR}/*pkg.tar.zst
else
    repo-add ${OUTPUT_DIR}/winesapos.db.tar.gz ${OUTPUT_DIR}/*pkg.tar.zst
fi
