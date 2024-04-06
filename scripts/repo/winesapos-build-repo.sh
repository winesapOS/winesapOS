#!/bin/bash

set -x

WORK_DIR="${WORK_DIR:-/tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(yay --noconfirm -S --removemake)
echo 'MAKEFLAGS="-j $(nproc)"' | sudo tee -a /etc/makepkg.conf

sudo pacman -S -y -y -u --noconfirm

# Install yay for helping install AUR build dependencies.
sudo -E ${CMD_PACMAN_INSTALL[*]} base-devel binutils cmake curl dkms git make tar wget
export YAY_VER="12.3.5"
sudo -E curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
sudo -E tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
sudo -E mv yay_${YAY_VER}_x86_64/yay /usr/bin/yay
sudo rm -rf ./yay*

failed_builds=0
makepkg_build_failure_check() {
    if ls -1 | grep pkg\.tar; then
        echo "${1} build PASSED"
    else
        failed_builds=$(expr ${failed_builds} + 1)
        echo "${1} build FAILED"
    fi
}

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
    makepkg_build_failure_check ${1}
}

# A proper git configuration is required to build some packages.
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

makepkg_fn apfsprogs-git
makepkg_fn fatx
makepkg_fn gfs2-utils
makepkg_fn linux-apfs-rw-dkms-git
makepkg_fn macbook12-spi-driver-dkms
makepkg_fn reiserfs-defrag
makepkg_fn ssdfs-tools
makepkg_fn zerotier-gui-git

# 'ceph-libs-bin' is a runtime dependency of 'ceph-bin'.
makepkg_fn ceph-libs-bin install
makepkg_fn ceph-bin

# 'snapd' is a runtime dependency of 'bauh'.
makepkg_fn snapd install
# 'bauh' is now provided by the Chaotic repository.
#makepkg_fn bauh

# 'gamescope-session-git' is a build dependency of 'gamescope-session-steam-git' and 'opengamepadui-session-git'.
makepkg_fn gamescope-session-git install
makepkg_fn gamescope-session-steam-git
# 'ryzenadj' is a build dependency of 'opengamepadui-bin'.
makepkg_fn ryzenadj install
makepkg_fn opengamepadui-bin install
makepkg_fn opengamepadui-session-git

WINESAPOS_REPO_BUILD_LINUX_GIT="${WINESAPOS_REPO_BUILD_LINUX_GIT:-false}"
if [[ "${WINESAPOS_REPO_BUILD_LINUX_GIT}" == "true" ]]; then
    # Import keys from the two main Linux kernel maintainers:
    ## Linus Torvalds:
    gpg --recv-keys 79BE3E4300411886
    ## Greg Kroah-Hartman:
    gpg --recv-keys 38DBBDC86092693E
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/linux-git.git
    cd linux-git
    makepkg -s --noconfirm
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
    makepkg_build_failure_check linux-git
fi

WINESAPOS_REPO_BUILD_MESA_GIT="${WINESAPOS_REPO_BUILD_MESA_GIT:-false}"
if [[ "${WINESAPOS_REPO_BUILD_MESA_GIT}" == "true" ]]; then
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/mesa-git.git
    cd mesa-git
    makepkg -s --noconfirm
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
    makepkg_build_failure_check mesa-git
    cd ${WORK_DIR}
    git clone https://aur.archlinux.org/lib32-mesa-git.git
    cd lib32-mesa-git
    makepkg -s --noconfirm
    cp ./*.pkg.tar.zst ${OUTPUT_DIR}
    makepkg_build_failure_check lib32-mesa-git
fi

# Build Pacman repository metadata.
WINESAPOS_REPO_BUILD_TESTING="${WINESAPOS_REPO_BUILD_TESTING:-false}"
if [[ "${WINESAPOS_REPO_BUILD_TESTING}" == "true" ]]; then
    repo-add ${OUTPUT_DIR}/winesapos-testing.db.tar.gz ${OUTPUT_DIR}/*pkg.tar.zst
else
    repo-add ${OUTPUT_DIR}/winesapos.db.tar.gz ${OUTPUT_DIR}/*pkg.tar.zst
fi

exit ${failed_builds}
