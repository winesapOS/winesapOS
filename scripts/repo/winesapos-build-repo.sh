#!/bin/sh

set -x

WORK_DIR="${WORK_DIR:-/tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(yay --noconfirm -S --removemake)
echo 'MAKEFLAGS="-j $(nproc)"' | sudo tee -a /etc/makepkg.conf

sudo pacman -S -y -y -u --noconfirm

# Install yay for helping install AUR build dependencies.
sudo -E ${CMD_PACMAN_INSTALL[*]} base-devel binutils cmake curl dkms git make tar wget
export YAY_VER="11.3.2"
sudo -E curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
sudo -E tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
sudo -E mv yay_${YAY_VER}_x86_64/yay /usr/bin/yay
sudo rm -rf ./yay*

# Usage: makepkg_fn <PACKAGE_NAME> [install|noinstall]
makepkg_fn() {
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/${1}.git
    cd ${1}
    if [[ "${2}" == "install" ]]; then
        makepkg -s --noconfirm -i
    else
        makepkg -s --noconfirm
    fi
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
}

makepkg_fn apfsprogs-git
makepkg_fn appimagelauncher
makepkg_fn appimagepool-appimage
makepkg_fn auto-cpufreq
makepkg_fn fatx
makepkg_fn firefox-esr-bin
makepkg_fn game-devices-udev
makepkg_fn gamescope-session-git install
makepkg_fn gamescope-session-steam-git
makepkg_fn opengamepadui-bin install
makepkg_fn opengamepadui-session-git
makepkg_fn heroic-games-launcher-bin
makepkg_fn hfsprogs
makepkg_fn lightdm-settings
makepkg_fn linux-apfs-rw-dkms-git
makepkg_fn ludusavi
makepkg_fn macbook12-spi-driver-dkms
makepkg_fn mbpfan-git
makepkg_fn mesa-steamos
makepkg_fn lib32-mesa-steamos
makepkg_fn oh-my-zsh-git
makepkg_fn paru
makepkg_fn plasma5-themes-vapos-steamos
makepkg_fn qdirstat
makepkg_fn reiserfs-defrag
makepkg_fn ssdfs-tools
makepkg_fn yay
makepkg_fn zerotier-gui-git

# A proper git configuration is required to build the Bcachefs packages.
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
## 'bcachefs-tools-git' requires 'libscrypt' to be installed to build it.
makepkg_fn libscrypt install
makepkg_fn bcachefs-tools-git
makepkg_fn linux-bcachefs-git

# 'snapd' is a runtime dependency of 'bauh'.
makepkg_fn snapd install
makepkg_fn bauh

# 'python-iniparse' is a build dependency for 'crudini'.
makepkg_fn python-iniparse install
makepkg_fn python-crudini

# This GPG key is required to build 'krathalans-apparmor-profiles-git'.
gpg --recv-keys C0F9AEE56E47D174
makepkg_fn krathalans-apparmor-profiles-git

# 'mangohud' is a build dependency for 'lib32-mangohud' and 'goverlay'.
makepkg_fn mangohud install
makepkg_fn lib32-mangohud
makepkg_fn goverlay
# 'replay-sorcery-git' is an optional dependency of 'mangohud'.
makepkg_fn replay-sorcery-git

# 'vkbasalt' is a build dependency for 'lib32-vkbasalt'.
makepkg_fn vkbasalt install
makepkg_fn lib32-vkbasalt

# This GPG key is required to build both  the 'zfs-utils' and 'zfs-dkms' packages.
gpg --recv-keys 6AD860EED4598027
# 'zfs-utils' is a build dependency for 'zfs-dkms'.
makepkg_fn zfs-utils install
makepkg_fn zfs-dkms

# Import keys from the two main Linux kernel maintainers:
## Linus Torvalds:
gpg --recv-keys 79BE3E4300411886
## Greg Kroah-Hartman:
gpg --recv-keys 38DBBDC86092693E
makepkg_fn linux-lts515

# Linux Neptune (includes headers).
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
